#!/usr/bin/env python3
"""Collect TI-field professional maps added after the prior analysis cutoff."""

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
OUT = Path(os.environ.get("DEEP_ANALYSIS_OUT", "research/deep-current-output"))
START_TS = int(datetime(2026, 8, 3, 7, 31, tzinfo=timezone.utc).timestamp())
END_TS = int(datetime(2026, 8, 3, 14, 50, tzinfo=timezone.utc).timestamp())

ALIASES = {
    "PARIVISION": ["parivision", "team vision", "pvision"],
    "Team Yandex": ["team yandex", "yandex"],
    "BetBoom Team": ["betboom team", "betboom", "bb team", "boomboys"],
    "Team Falcons": ["team falcons", "falcons"],
    "Team Spirit": ["team spirit", "spirit"],
    "Nigma Galaxy": ["nigma galaxy", "nigma", "ngx"],
    "Vici Gaming": ["vici gaming", "vici", "vg"],
    "Aurora Gaming": ["aurora gaming", "aurora"],
    "Team Liquid": ["team liquid", "liquid"],
    "LGD Gaming": ["lgd gaming", "lgd"],
    "IRON WING / 1w": ["iron wing", "1w team", "1w", "1win team", "1win", "tundra esports", "tundra"],
    "Xtreme Gaming": ["xtreme gaming", "xtreme", "xg"],
    "OG": ["og", "og esports"],
    "GamerLegion": ["gamerlegion", "gamer legion"],
    "Team Resilience": ["team resilience", "resilience"],
    "HULIGANI / L1 Team": ["huligani", "l1 team", "l1ga team", "l1ga"],
}


def normalize(value: object) -> str:
    text = str(value or "").casefold().strip()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return " ".join(text.split())


NORMALIZED = {
    canonical: {normalize(alias) for alias in aliases + [canonical]}
    for canonical, aliases in ALIASES.items()
}


def canonical_for(name: object) -> str | None:
    cleaned = normalize(name)
    if not cleaned:
        return None
    for canonical, aliases in NORMALIZED.items():
        if cleaned in aliases:
            return canonical
    return None


def get_json(path: str, params: dict[str, object] | None = None, attempts: int = 8):
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    delay = 2.0
    for attempt in range(attempts):
        try:
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "ti-predictions-current-analysis/1.0"},
            )
            with urllib.request.urlopen(request, timeout=75) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code not in (429, 500, 502, 503, 504) or attempt == attempts - 1:
                raise
            retry = exc.headers.get("Retry-After")
            wait = float(retry) if retry else delay
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            if attempt == attempts - 1:
                raise
            wait = delay
        time.sleep(wait)
        delay = min(delay * 1.8, 45)
    raise RuntimeError(f"Unable to fetch {url}")


def at_minute(values: object, minute: int, sign: int) -> float | None:
    if not isinstance(values, list) or not values:
        return None
    index = min(minute, len(values) - 1)
    value = values[index]
    if isinstance(value, (int, float)) and math.isfinite(value):
        return sign * float(value)
    return None


def signed_values(values: object, sign: int, start_minute: int = 0) -> list[float]:
    if not isinstance(values, list):
        return []
    result: list[float] = []
    for value in values[start_minute:]:
        if isinstance(value, (int, float)) and math.isfinite(value):
            result.append(sign * float(value))
    return result


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    seen: set[str] = set()
    for row in rows:
        for key in row:
            if key not in seen:
                fields.append(key)
                seen.add(key)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    pro_matches: list[dict[str, object]] = []
    seen_ids: set[int] = set()
    less_than: int | None = None
    pages = 0
    while pages < 12:
        params = {"less_than_match_id": less_than} if less_than else None
        batch = get_json("/proMatches", params)
        if not batch:
            break
        fresh = [row for row in batch if int(row.get("match_id") or 0) not in seen_ids]
        if not fresh:
            break
        for row in fresh:
            match_id = int(row.get("match_id") or 0)
            if match_id:
                seen_ids.add(match_id)
                pro_matches.append(row)
        pages += 1
        oldest = min(int(row.get("start_time") or END_TS) for row in batch)
        ids = [int(row.get("match_id") or 0) for row in batch if row.get("match_id")]
        less_than = min(ids) if ids else None
        if oldest < START_TS - 7200:
            break
        time.sleep(1.1)

    candidates: dict[int, dict[str, object]] = {}
    for row in pro_matches:
        start_time = int(row.get("start_time") or 0)
        if not (START_TS < start_time <= END_TS):
            continue
        radiant = canonical_for(row.get("radiant_name"))
        dire = canonical_for(row.get("dire_name"))
        if radiant or dire:
            candidates[int(row["match_id"])] = row

    map_rows: list[dict[str, object]] = []
    player_rows: list[dict[str, object]] = []
    draft_rows: list[dict[str, object]] = []
    objective_rows: list[dict[str, object]] = []
    teamfight_rows: list[dict[str, object]] = []
    failures: list[dict[str, object]] = []
    observed = defaultdict(int)

    for index, match_id in enumerate(sorted(candidates), start=1):
        try:
            detail = get_json(f"/matches/{match_id}")
        except Exception as exc:  # noqa: BLE001
            failures.append({"match_id": match_id, "error": repr(exc)})
            continue

        start_time = int(detail.get("start_time") or candidates[match_id].get("start_time") or 0)
        radiant_name = detail.get("radiant_name") or candidates[match_id].get("radiant_name") or ""
        dire_name = detail.get("dire_name") or candidates[match_id].get("dire_name") or ""
        radiant_canonical = canonical_for(radiant_name)
        dire_canonical = canonical_for(dire_name)
        radiant_win = bool(detail.get("radiant_win"))
        duration = int(detail.get("duration") or 0)
        gold = detail.get("radiant_gold_adv") or []
        xp = detail.get("radiant_xp_adv") or []

        sides = [
            (radiant_canonical, radiant_name, dire_name, True),
            (dire_canonical, dire_name, radiant_name, False),
        ]
        for canonical, display_name, opponent_name, is_radiant in sides:
            if canonical is None:
                continue
            sign = 1 if is_radiant else -1
            won = radiant_win if is_radiant else not radiant_win
            all_gold = signed_values(gold, sign)
            post15_gold = signed_values(gold, sign, 15)
            all_xp = signed_values(xp, sign)
            observed[canonical] += 1
            row: dict[str, object] = {
                "match_id": match_id,
                "start_time_utc": datetime.fromtimestamp(start_time, timezone.utc).isoformat(),
                "team": canonical,
                "source_team_name": display_name,
                "opponent": canonical_for(opponent_name) or opponent_name,
                "opponent_source_name": opponent_name,
                "side": "Radiant" if is_radiant else "Dire",
                "win": int(won),
                "duration_seconds": duration,
                "duration_minutes": round(duration / 60, 3) if duration else None,
                "league_id": detail.get("leagueid") or candidates[match_id].get("leagueid"),
                "league_name": detail.get("league_name") or candidates[match_id].get("league_name") or "",
                "series_id": detail.get("series_id") or "",
                "series_type": detail.get("series_type") or "",
                "patch_id": detail.get("patch") or "",
                "parsed": int(bool(detail.get("version"))),
                "max_gold_lead": max(all_gold) if all_gold else None,
                "max_gold_deficit": min(all_gold) if all_gold else None,
                "post15_max_gold_lead": max(post15_gold) if post15_gold else None,
                "post15_max_gold_deficit": min(post15_gold) if post15_gold else None,
                "post15_throw_5000": int(bool((not won) and post15_gold and max(post15_gold) >= 5000)),
                "post15_throw_3000": int(bool((not won) and post15_gold and max(post15_gold) >= 3000)),
                "post15_comeback_5000": int(bool(won and post15_gold and min(post15_gold) <= -5000)),
                "post15_comeback_3000": int(bool(won and post15_gold and min(post15_gold) <= -3000)),
                "final_gold_adv": all_gold[-1] if all_gold else None,
                "final_xp_adv": all_xp[-1] if all_xp else None,
            }
            for minute in (10, 15, 20, 25, 30):
                row[f"gold_adv_{minute}"] = at_minute(gold, minute, sign)
                row[f"xp_adv_{minute}"] = at_minute(xp, minute, sign)
            map_rows.append(row)

        for order, item in enumerate(detail.get("picks_bans") or []):
            draft_rows.append({
                "match_id": match_id,
                "order": item.get("order", order),
                "is_pick": int(bool(item.get("is_pick"))),
                "draft_side": "Radiant" if int(item.get("team") or 0) == 0 else "Dire",
                "hero_id": item.get("hero_id") or 0,
            })

        for player in detail.get("players") or []:
            is_radiant = bool(player.get("isRadiant"))
            canonical = radiant_canonical if is_radiant else dire_canonical
            if canonical is None:
                continue
            player_rows.append({
                "match_id": match_id,
                "team": canonical,
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
                "kill_participation": player.get("kill_streaks") or "",
                "buyback_count": len(player.get("buyback_log") or []),
            })

        for order, objective in enumerate(detail.get("objectives") or []):
            objective_rows.append({
                "match_id": match_id,
                "order": order,
                "time_seconds": objective.get("time") or 0,
                "type": objective.get("type") or "",
                "team": objective.get("team") if objective.get("team") is not None else "",
                "slot": objective.get("slot") if objective.get("slot") is not None else "",
                "key": objective.get("key") if objective.get("key") is not None else "",
            })

        for fight_index, fight in enumerate(detail.get("teamfights") or []):
            teamfight_rows.append({
                "match_id": match_id,
                "fight_index": fight_index,
                "start": fight.get("start") or 0,
                "end": fight.get("end") or 0,
                "last_death": fight.get("last_death") or 0,
                "deaths": fight.get("deaths") or 0,
                "players_json": json.dumps(fight.get("players") or [], separators=(",", ":")),
            })

        print(f"Fetched {index}/{len(candidates)} match {match_id}")
        time.sleep(1.1)

    write_csv(OUT / "maps_delta.csv", map_rows)
    write_csv(OUT / "players_delta.csv", player_rows)
    write_csv(OUT / "drafts_delta.csv", draft_rows)
    write_csv(OUT / "objectives_delta.csv", objective_rows)
    write_csv(OUT / "teamfights_delta.csv", teamfight_rows)
    write_csv(OUT / "failures.csv", failures)

    summary = {
        "window_start_utc": datetime.fromtimestamp(START_TS, timezone.utc).isoformat(),
        "window_end_utc": datetime.fromtimestamp(END_TS, timezone.utc).isoformat(),
        "pro_match_pages": pages,
        "candidate_unique_maps": len(candidates),
        "fetched_unique_maps": len({int(row["match_id"]) for row in map_rows}),
        "team_perspective_rows": len(map_rows),
        "observed_team_map_counts": dict(sorted(observed.items())),
        "failures": failures,
    }
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
