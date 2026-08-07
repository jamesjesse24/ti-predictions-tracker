#!/usr/bin/env python3
"""Collect all TI-field professional maps after the previous full-model cutoff."""
from __future__ import annotations

import csv, json, math, os, re, time
import urllib.error, urllib.parse, urllib.request
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

API = "https://api.opendota.com/api"
OUT = Path(os.environ.get("DEEP_ANALYSIS_OUT", "research/deep-refresh-output"))
START_TS = int(datetime(2026, 8, 3, 14, 50, tzinfo=timezone.utc).timestamp())
END_TS = int(datetime(2026, 8, 4, 22, 24, tzinfo=timezone.utc).timestamp())
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

def norm(v):
    return " ".join(re.sub(r"[^a-z0-9]+", " ", str(v or "").casefold()).split())
NORM = {k: {norm(x) for x in vals + [k]} for k, vals in ALIASES.items()}
def canonical(v):
    n = norm(v)
    for k, vals in NORM.items():
        if n in vals:
            return k
    return None

def get_json(path, params=None, attempts=8):
    url = API + path + (("?" + urllib.parse.urlencode(params)) if params else "")
    delay = 2.0
    for attempt in range(attempts):
        try:
            req = urllib.request.Request(url, headers={"User-Agent":"ti-deep-refresh/2.0"})
            with urllib.request.urlopen(req, timeout=75) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code not in (429,500,502,503,504) or attempt == attempts-1:
                raise
            wait = float(e.headers.get("Retry-After") or delay)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            if attempt == attempts-1:
                raise
            wait = delay
        time.sleep(wait); delay = min(delay*1.8, 45)
    raise RuntimeError(url)

def at(values, minute, sign):
    if not isinstance(values, list) or not values: return None
    v = values[min(minute, len(values)-1)]
    return sign*float(v) if isinstance(v,(int,float)) and math.isfinite(v) else None

def signed(values, sign, start=0):
    if not isinstance(values, list): return []
    return [sign*float(v) for v in values[start:] if isinstance(v,(int,float)) and math.isfinite(v)]

def write_csv(path, rows):
    if not rows:
        path.write_text("", encoding="utf-8"); return
    fields=[]; seen=set()
    for row in rows:
        for k in row:
            if k not in seen: seen.add(k); fields.append(k)
    with path.open("w", newline="", encoding="utf-8") as f:
        w=csv.DictWriter(f, fieldnames=fields); w.writeheader(); w.writerows(rows)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pro=[]; ids=set(); less=None; pages=0
    while pages < 24:
        batch=get_json("/proMatches", {"less_than_match_id":less} if less else None)
        if not batch: break
        fresh=[r for r in batch if int(r.get("match_id") or 0) not in ids]
        if not fresh: break
        for r in fresh:
            mid=int(r.get("match_id") or 0)
            if mid: ids.add(mid); pro.append(r)
        pages += 1
        oldest=min(int(r.get("start_time") or END_TS) for r in batch)
        valid=[int(r["match_id"]) for r in batch if r.get("match_id")]
        less=min(valid) if valid else None
        if oldest < START_TS-7200: break
        time.sleep(1.05)

    candidates={}
    for r in pro:
        st=int(r.get("start_time") or 0)
        if START_TS < st <= END_TS and (canonical(r.get("radiant_name")) or canonical(r.get("dire_name"))):
            candidates[int(r["match_id"])]=r

    maps=[]; players=[]; drafts=[]; objectives=[]; fights=[]; failures=[]; observed=defaultdict(int)
    raw=(OUT/"match_details.jsonl").open("w", encoding="utf-8")
    for index, mid in enumerate(sorted(candidates),1):
        try:
            d=get_json(f"/matches/{mid}")
        except Exception as e:
            failures.append({"match_id":mid,"error":repr(e)}); continue
        raw.write(json.dumps(d, ensure_ascii=False)+"\n")
        st=int(d.get("start_time") or candidates[mid].get("start_time") or 0)
        rn=d.get("radiant_name") or candidates[mid].get("radiant_name") or ""
        dn=d.get("dire_name") or candidates[mid].get("dire_name") or ""
        rc,dc=canonical(rn),canonical(dn)
        rw=bool(d.get("radiant_win")); dur=int(d.get("duration") or 0)
        gold=d.get("radiant_gold_adv") or []; xp=d.get("radiant_xp_adv") or []
        for can,display,opp,israd in [(rc,rn,dn,True),(dc,dn,rn,False)]:
            if not can: continue
            sign=1 if israd else -1; won=rw if israd else not rw
            g=signed(gold,sign); g15=signed(gold,sign,15); x=signed(xp,sign)
            row={
                "match_id":mid,"start_time_utc":datetime.fromtimestamp(st,timezone.utc).isoformat(),
                "team":can,"source_team_name":display,"opponent":canonical(opp) or opp,
                "opponent_source_name":opp,"side":"Radiant" if israd else "Dire","win":int(won),
                "duration_seconds":dur,"duration_minutes":round(dur/60,3) if dur else None,
                "league_id":d.get("leagueid") or candidates[mid].get("leagueid"),
                "league_name":d.get("league_name") or candidates[mid].get("league_name") or "",
                "series_id":d.get("series_id") or "","series_type":d.get("series_type") or "",
                "patch_id":d.get("patch") or "","parsed":int(bool(d.get("version"))),
                "max_gold_lead":max(g) if g else None,"max_gold_deficit":min(g) if g else None,
                "post15_max_gold_lead":max(g15) if g15 else None,"post15_max_gold_deficit":min(g15) if g15 else None,
                "post15_throw_5000":int(bool((not won) and g15 and max(g15)>=5000)),
                "post15_throw_3000":int(bool((not won) and g15 and max(g15)>=3000)),
                "post15_comeback_5000":int(bool(won and g15 and min(g15)<=-5000)),
                "post15_comeback_3000":int(bool(won and g15 and min(g15)<=-3000)),
                "final_gold_adv":g[-1] if g else None,"final_xp_adv":x[-1] if x else None,
            }
            for m in (10,15,20,25,30): row[f"gold_adv_{m}"]=at(gold,m,sign); row[f"xp_adv_{m}"]=at(xp,m,sign)
            maps.append(row); observed[can]+=1
        for order,item in enumerate(d.get("picks_bans") or []):
            drafts.append({"match_id":mid,"order":item.get("order",order),"is_pick":int(bool(item.get("is_pick"))),"draft_side":"Radiant" if int(item.get("team") or 0)==0 else "Dire","hero_id":item.get("hero_id") or 0})
        for p in d.get("players") or []:
            israd=bool(p.get("isRadiant")); can=rc if israd else dc
            if not can: continue
            players.append({"match_id":mid,"team":can,"account_id":p.get("account_id") or "","personaname":p.get("personaname") or "","name":p.get("name") or "","hero_id":p.get("hero_id") or 0,"kills":p.get("kills") or 0,"deaths":p.get("deaths") or 0,"assists":p.get("assists") or 0,"last_hits":p.get("last_hits") or 0,"denies":p.get("denies") or 0,"gold_per_min":p.get("gold_per_min") or 0,"xp_per_min":p.get("xp_per_min") or 0,"net_worth":p.get("net_worth") or 0,"hero_damage":p.get("hero_damage") or 0,"tower_damage":p.get("tower_damage") or 0,"hero_healing":p.get("hero_healing") or 0,"buyback_count":len(p.get("buyback_log") or [])})
        for order,o in enumerate(d.get("objectives") or []):
            objectives.append({"match_id":mid,"order":order,"time_seconds":o.get("time") or 0,"type":o.get("type") or "","team":o.get("team") if o.get("team") is not None else "","slot":o.get("slot") if o.get("slot") is not None else "","key":o.get("key") if o.get("key") is not None else ""})
        for fi,f in enumerate(d.get("teamfights") or []):
            fights.append({"match_id":mid,"fight_index":fi,"start":f.get("start") or 0,"end":f.get("end") or 0,"last_death":f.get("last_death") or 0,"deaths":f.get("deaths") or 0,"players_json":json.dumps(f.get("players") or [],separators=(",",":"))})
        print(f"Fetched {index}/{len(candidates)} {mid}"); time.sleep(1.05)
    raw.close()
    for name,rows in [("maps_delta.csv",maps),("players_delta.csv",players),("drafts_delta.csv",drafts),("objectives_delta.csv",objectives),("teamfights_delta.csv",fights),("failures.csv",failures)]: write_csv(OUT/name,rows)
    summary={"window_start_utc":datetime.fromtimestamp(START_TS,timezone.utc).isoformat(),"window_end_utc":datetime.fromtimestamp(END_TS,timezone.utc).isoformat(),"pro_match_pages":pages,"candidate_unique_maps":len(candidates),"fetched_unique_maps":len({int(r["match_id"]) for r in maps}),"team_perspective_rows":len(maps),"observed_team_map_counts":dict(sorted(observed.items())),"failures":failures}
    (OUT/"summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
    print(json.dumps(summary,indent=2))

if __name__ == "__main__": main()
