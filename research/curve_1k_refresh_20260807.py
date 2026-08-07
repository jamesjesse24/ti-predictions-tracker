#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

API = "https://api.opendota.com/api"
OUT = Path(os.environ.get("DEEP_ANALYSIS_OUT", "research/curve-1k-refresh-output"))
HIST_START_TS = int(datetime(2026, 1, 1, 0, 0, tzinfo=timezone.utc).timestamp())
END_TS = int(datetime(2026, 8, 7, 7, 56, tzinfo=timezone.utc).timestamp())
MAX_CANDIDATE_MAPS = 1000
MAX_PRO_PAGES = 300
REQUEST_DELAY = 1.05

TEAM_IDS = {
    "PARIVISION": {9824702, 9572001},
    "Team Yandex": {9823272},
    "BetBoom Team": {8255888, 10163435},
    "Team Falcons": {9247354},
    "Team Spirit": {7119388},
    "Nigma Galaxy": {10136357},
    "Vici Gaming": {726228},
    "Aurora Gaming": {9467224},
    "Team Liquid": {2163},
    "LGD Gaming": {10150538},
    "IRON WING / 1w": {10182357},
    "Xtreme Gaming": {8261500, 10208071},
    "OG": {2586976},
    "GamerLegion": {9964962},
    "Team Resilience": {10207984, 5017210},
    "HULIGANI / L1 Team": {10149530, 10182299, 10208009},
}

ALIASES = {
    "PARIVISION": ["parivision", "team vision", "pvision"],
    "Team Yandex": ["team yandex", "yandex"],
    "BetBoom Team": ["betboom team", "betboom", "bb team"],
    "Team Falcons": ["team falcons", "falcons"],
    "Team Spirit": ["team spirit", "spirit"],
    "Nigma Galaxy": ["nigma galaxy", "nigma", "ngx"],
    "Vici Gaming": ["vici gaming", "vici"],
    "Aurora Gaming": ["aurora gaming", "aurora"],
    "Team Liquid": ["team liquid", "liquid"],
    "LGD Gaming": ["lgd gaming", "lgd"],
    "IRON WING / 1w": ["iron wing", "1w team", "1w", "1win team", "1win"],
    "Xtreme Gaming": ["xtreme gaming", "xtreme", "xg"],
    "OG": ["og", "og esports"],
    "GamerLegion": ["gamerlegion", "gamer legion"],
    "Team Resilience": ["team resilience", "resilience"],
    "HULIGANI / L1 Team": ["huligani", "l1 team", "l1ga team", "l1ga"],
}

def norm(v):
    return " ".join(re.sub(r"[^a-z0-9]+", " ", str(v or "").casefold()).split())

NORM = {k: {norm(x) for x in vals + [k]} for k, vals in ALIASES.items()}
ID_TO_TEAM = {tid: team for team, ids in TEAM_IDS.items() for tid in ids}


def canonical(name, team_id=None):
    try:
        tid = int(team_id or 0)
    except Exception:
        tid = 0
    if tid in ID_TO_TEAM:
        return ID_TO_TEAM[tid]
    n = norm(name)
    for team, aliases in NORM.items():
        if n in aliases:
            return team
    return None


def get_json(path, params=None, attempts=8):
    url = API + path + (("?" + urllib.parse.urlencode(params)) if params else "")
    delay = 2.0
    for attempt in range(attempts):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "ti-curve-1k-refresh/20260807"})
            with urllib.request.urlopen(req, timeout=75) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code not in (429, 500, 502, 503, 504) or attempt == attempts - 1:
                raise
            wait = float(exc.headers.get("Retry-After") or delay)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            if attempt == attempts - 1:
                raise
            wait = delay
        time.sleep(wait)
        delay = min(delay * 1.8, 45)
    raise RuntimeError(url)


def at(values, minute, sign):
    if not isinstance(values, list) or not values:
        return None
    value = values[min(minute, len(values) - 1)]
    if isinstance(value, (int, float)) and math.isfinite(value):
        return sign * float(value)
    return None


def signed(values, sign, start=0):
    if not isinstance(values, list):
        return []
    return [sign * float(v) for v in values[start:] if isinstance(v, (int, float)) and math.isfinite(v)]


def write_csv(path, rows):
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields, seen = [], set()
    for row in rows:
        for key in row:
            if key not in seen:
                seen.add(key)
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pro, ids, candidates = [], set(), {}
    less = None
    pages = 0

    while pages < MAX_PRO_PAGES:
        batch = get_json("/proMatches", {"less_than_match_id": less} if less else None)
        if not batch:
            break
        fresh = [row for row in batch if int(row.get("match_id") or 0) not in ids]
        if not fresh:
            break
        for row in fresh:
            mid = int(row.get("match_id") or 0)
            if not mid:
                continue
            ids.add(mid)
            pro.append(row)
            st = int(row.get("start_time") or 0)
            rc = canonical(row.get("radiant_name"), row.get("radiant_team_id"))
            dc = canonical(row.get("dire_name"), row.get("dire_team_id"))
            if HIST_START_TS <= st <= END_TS and (rc or dc):
                candidates[mid] = row
        pages += 1
        oldest = min(int(row.get("start_time") or END_TS) for row in batch)
        valid = [int(row["match_id"]) for row in batch if row.get("match_id")]
        less = min(valid) if valid else None
        if oldest < HIST_START_TS - 7200 or len(candidates) >= MAX_CANDIDATE_MAPS:
            break
        time.sleep(REQUEST_DELAY)

    selected = sorted(candidates.values(), key=lambda r: int(r.get("start_time") or 0), reverse=True)[:MAX_CANDIDATE_MAPS]
    selected = sorted(selected, key=lambda r: int(r.get("start_time") or 0))

    maps, players, drafts, objectives, fights, failures = [], [], [], [], [], []
    observed = defaultdict(int)
    raw = (OUT / "match_details.jsonl").open("w", encoding="utf-8")

    for index, candidate in enumerate(selected, 1):
        mid = int(candidate["match_id"])
        try:
            detail = get_json(f"/matches/{mid}")
        except Exception as exc:
            failures.append({"match_id": mid, "error": repr(exc)})
            continue
        raw.write(json.dumps(detail, ensure_ascii=False) + "\n")

        st = int(detail.get("start_time") or candidate.get("start_time") or 0)
        rn = detail.get("radiant_name") or candidate.get("radiant_name") or ""
        dn = detail.get("dire_name") or candidate.get("dire_name") or ""
        rid = detail.get("radiant_team_id") or candidate.get("radiant_team_id") or 0
        did = detail.get("dire_team_id") or candidate.get("dire_team_id") or 0
        rc, dc = canonical(rn, rid), canonical(dn, did)
        rw = bool(detail.get("radiant_win"))
        dur = int(detail.get("duration") or 0)
        gold = detail.get("radiant_gold_adv") or []
        xp = detail.get("radiant_xp_adv") or []

        for can, display, team_id, opp_name, opp_id, is_rad in [
            (rc, rn, rid, dn, did, True),
            (dc, dn, did, rn, rid, False),
        ]:
            if not can:
                continue
            sign = 1 if is_rad else -1
            won = rw if is_rad else not rw
            g = signed(gold, sign)
            g15 = signed(gold, sign, 15)
            x = signed(xp, sign)
            row = {
                "match_id": mid,
                "start_time_utc": datetime.fromtimestamp(st, timezone.utc).isoformat(),
                "team": can,
                "team_id": team_id or "",
                "source_team_name": display,
                "opponent": canonical(opp_name, opp_id) or opp_name,
                "opponent_id": opp_id or "",
                "opponent_source_name": opp_name,
                "side": "Radiant" if is_rad else "Dire",
                "win": int(won),
                "duration_seconds": dur,
                "duration_minutes": round(dur / 60, 3) if dur else None,
                "league_id": detail.get("leagueid") or candidate.get("leagueid"),
                "league_name": detail.get("league_name") or candidate.get("league_name") or "",
                "series_id": detail.get("series_id") or "",
                "series_type": detail.get("series_type") or "",
                "patch_id": detail.get("patch") or "",
                "parsed": int(bool(detail.get("version"))),
                "max_gold_lead": max(g) if g else None,
                "max_gold_deficit": min(g) if g else None,
                "post15_max_gold_lead": max(g15) if g15 else None,
                "post15_max_gold_deficit": min(g15) if g15 else None,
                "post15_throw_5000": int(bool((not won) and g15 and max(g15) >= 5000)),
                "post15_throw_3000": int(bool((not won) and g15 and max(g15) >= 3000)),
                "post15_comeback_5000": int(bool(won and g15 and min(g15) <= -5000)),
                "post15_comeback_3000": int(bool(won and g15 and min(g15) <= -3000)),
                "final_gold_adv": g[-1] if g else None,
                "final_xp_adv": x[-1] if x else None,
            }
            for minute in (5, 10, 15, 20, 25, 30):
                row[f"gold_adv_{minute}"] = at(gold, minute, sign)
                row[f"xp_adv_{minute}"] = at(xp, minute, sign)
            maps.append(row)
            observed[can] += 1

        for order, item in enumerate(detail.get("picks_bans") or []):
            drafts.append({
                "match_id": mid,
                "order": item.get("order", order),
                "is_pick": int(bool(item.get("is_pick"))),
                "draft_side": "Radiant" if int(item.get("team") or 0) == 0 else "Dire",
                "hero_id": item.get("hero_id") or 0,
            })

        for player in detail.get("players") or []:
            is_rad = bool(player.get("isRadiant"))
            can = rc if is_rad else dc
            if not can:
                continue
            players.append({
                "match_id": mid,
                "team": can,
                "account_id": player.get("account_id") or "",
                "personaname": player.get("personaname") or "",
                "name": player.get("name") or "",
                "hero_id": player.get("hero_id") or 0,
                "kills": player.get("kills") or 0,
                "deaths": player.get("deaths") or 0,
                "assists": player.get("assists") or 0,
                "last_hits": player.get("last_hits") or 0,
                "denies": player.get("denies") or 0,
                "gold_per_min": player.get("gold_per_min") or 0,
                "xp_per_min": player.get("xp_per_min") or 0,
                "net_worth": player.get("net_worth") or 0,
                "hero_damage": player.get("hero_damage") or 0,
                "tower_damage": player.get("tower_damage") or 0,
                "hero_healing": player.get("hero_healing") or 0,
                "buyback_count": len(player.get("buyback_log") or []),
            })

        for order, objective in enumerate(detail.get("objectives") or []):
            objectives.append({
                "match_id": mid,
                "order": order,
                "time_seconds": objective.get("time") or 0,
                "type": objective.get("type") or "",
                "team": objective.get("team") if objective.get("team") is not None else "",
                "slot": objective.get("slot") if objective.get("slot") is not None else "",
                "key": objective.get("key") if objective.get("key") is not None else "",
            })

        for fi, fight in enumerate(detail.get("teamfights") or []):
            fights.append({
                "match_id": mid,
                "fight_index": fi,
                "start": fight.get("start") or 0,
                "end": fight.get("end") or 0,
                "last_death": fight.get("last_death") or 0,
                "deaths": fight.get("deaths") or 0,
                "players_json": json.dumps(fight.get("players") or [], separators=(",", ":")),
            })

        print(f"Fetched {index}/{len(selected)} {mid}")
        time.sleep(REQUEST_DELAY)

    raw.close()
    for name, rows in [
        ("maps.csv", maps),
        ("players.csv", players),
        ("drafts.csv", drafts),
        ("objectives.csv", objectives),
        ("teamfights.csv", fights),
        ("failures.csv", failures),
    ]:
        write_csv(OUT / name, rows)

    summary = {
        "historical_window_start_utc": datetime.fromtimestamp(HIST_START_TS, timezone.utc).isoformat(),
        "window_end_utc": datetime.fromtimestamp(END_TS, timezone.utc).isoformat(),
        "pro_match_pages": pages,
        "candidate_maps_seen": len(candidates),
        "selected_unique_maps": len(selected),
        "fetched_unique_maps": len({int(row["match_id"]) for row in maps}),
        "team_perspective_rows": len(maps),
        "observed_team_map_counts": dict(sorted(observed.items())),
        "failures": failures,
        "target_maps": MAX_CANDIDATE_MAPS,
    }
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))

if __name__ == "__main__":
    main()
