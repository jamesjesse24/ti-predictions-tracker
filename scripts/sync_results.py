#!/usr/bin/env python3
"""Generate data/live.json from OpenDota league match data.

The script is dependency-free so GitHub Actions can run it with standard
Python. It discovers the TI 2026 league automatically unless
OPENDOTA_LEAGUE_ID is provided.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TEAMS_PATH = ROOT / "data" / "teams.json"
LIVE_PATH = ROOT / "data" / "live.json"
API_BASE = "https://api.opendota.com/api"
EVENT_QUERY = os.getenv("EVENT_QUERY", "The International 2026")
LEAGUE_ID_OVERRIDE = os.getenv("OPENDOTA_LEAGUE_ID", "").strip()


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]", "", (value or "").lower())


def normalize_logo_url(value: Any) -> str | None:
    if not value:
        return None
    url = str(value).strip()
    if not url:
        return None
    if url.startswith("//"):
        return f"https:{url}"
    if url.startswith("/"):
        return f"https://www.opendota.com{url}"
    return url


def get_json(path: str) -> Any:
    query: dict[str, str] = {}
    api_key = os.getenv("OPENDOTA_API_KEY", "").strip()
    if api_key:
        query["api_key"] = api_key
    url = f"{API_BASE}{path}"
    if query:
        url = f"{url}?{urllib.parse.urlencode(query)}"
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "ti-predictions-tracker/3.0 (+github.com/jamesjesse24/ti-predictions-tracker)",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def load_json(path: Path, fallback: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return fallback


def choose_league() -> tuple[int, str] | None:
    if LEAGUE_ID_OVERRIDE:
        return int(LEAGUE_ID_OVERRIDE), EVENT_QUERY

    leagues = get_json("/leagues")
    if not isinstance(leagues, list):
        return None

    query_norm = normalize(EVENT_QUERY)
    candidates: list[tuple[int, str, int]] = []
    for item in leagues:
        if not isinstance(item, dict):
            continue
        league_id = int(item.get("leagueid") or item.get("league_id") or 0)
        name = str(item.get("name") or "")
        name_norm = normalize(name)
        if not league_id:
            continue
        score = 0
        if query_norm and query_norm == name_norm:
            score = 100
        elif "international" in name_norm and "2026" in name_norm:
            score = 90
        elif "international" in name_norm and "26" in name_norm:
            score = 70
        if score:
            candidates.append((league_id, name, score))

    if not candidates:
        return None
    candidates.sort(key=lambda item: (item[2], item[0]), reverse=True)
    league_id, name, _ = candidates[0]
    return league_id, name


def build_alias_index(config: list[dict[str, Any]]) -> dict[str, str]:
    index: dict[str, str] = {}
    for team in config:
        canonical = str(team["name"])
        values = [canonical, team.get("clientName", ""), *(team.get("aliases") or [])]
        for value in values:
            key = normalize(str(value))
            if key:
                index[key] = canonical
    return index


def resolve_team(
    raw_name: str | None,
    team_id: int | None,
    id_to_name: dict[int, str],
    aliases: dict[str, str],
) -> str | None:
    names = [raw_name]
    if team_id:
        names.append(id_to_name.get(team_id))
    for name in names:
        key = normalize(name)
        if key in aliases:
            return aliases[key]
    return None


def required_series_wins(series_type: int, series_id: int) -> int:
    if series_type == 2:
        return 3
    if series_type == 0 and series_id == 0:
        return 1
    return 2


def stable_hash(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def write_if_changed(payload: dict[str, Any]) -> bool:
    previous = load_json(LIVE_PATH, {})
    comparable_new = {key: value for key, value in payload.items() if key != "generatedAt"}
    comparable_old = {key: value for key, value in previous.items() if key != "generatedAt"}
    if stable_hash(comparable_new) == stable_hash(comparable_old):
        print("No result changes detected.")
        return False
    payload["generatedAt"] = now_iso()
    LIVE_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Updated {LIVE_PATH.relative_to(ROOT)}")
    return True


def waiting_payload(message: str) -> dict[str, Any]:
    config = load_json(TEAMS_PATH, [])
    return {
        "schemaVersion": 3,
        "status": "waiting",
        "source": "OpenDota",
        "message": message,
        "generatedAt": None,
        "leagueName": None,
        "leagueId": None,
        "teams": [
            {
                "name": team["name"],
                "clientName": team["clientName"],
                "logoUrl": normalize_logo_url(team.get("logoUrl")),
                "seriesWins": 0,
                "seriesLosses": 0,
                "mapWins": 0,
                "mapLosses": 0,
                "actual": "Pending",
                "lastMatchAt": None,
            }
            for team in config
        ],
        "series": [],
    }


def main() -> int:
    config = load_json(TEAMS_PATH, [])
    if not isinstance(config, list) or len(config) != 16:
        raise RuntimeError("data/teams.json must contain exactly 16 teams")

    league = choose_league()
    if league is None:
        write_if_changed(waiting_payload("Waiting for the TI 2026 OpenDota league feed."))
        return 0

    league_id, league_name = league
    matches = get_json(f"/leagues/{league_id}/matches")
    league_teams = get_json(f"/leagues/{league_id}/teams")
    if not isinstance(matches, list):
        raise RuntimeError("OpenDota league matches response was not a list")

    aliases = build_alias_index(config)
    id_to_name: dict[int, str] = {}
    id_to_logo: dict[int, str] = {}
    if isinstance(league_teams, list):
        for item in league_teams:
            if not isinstance(item, dict):
                continue
            team_id = int(item.get("team_id") or item.get("teamid") or 0)
            name = str(item.get("name") or item.get("tag") or "")
            logo = normalize_logo_url(item.get("logo_url") or item.get("logo"))
            if team_id and name:
                id_to_name[team_id] = name
            if team_id and logo:
                id_to_logo[team_id] = logo

    canonical_logos: dict[str, str] = {}
    if isinstance(league_teams, list):
        for item in league_teams:
            if not isinstance(item, dict):
                continue
            team_id = int(item.get("team_id") or item.get("teamid") or 0)
            name = str(item.get("name") or item.get("tag") or "")
            canonical = resolve_team(name, team_id, id_to_name, aliases)
            logo = id_to_logo.get(team_id) or normalize_logo_url(item.get("logo_url") or item.get("logo"))
            if canonical and logo:
                canonical_logos[canonical] = logo

    grouped: dict[str, dict[str, Any]] = {}
    sorted_matches = sorted(
        (item for item in matches if isinstance(item, dict)),
        key=lambda item: int(item.get("start_time") or 0),
    )

    for match in sorted_matches:
        radiant_id = int(match.get("radiant_team_id") or 0)
        dire_id = int(match.get("dire_team_id") or 0)
        radiant = resolve_team(match.get("radiant_name"), radiant_id, id_to_name, aliases)
        dire = resolve_team(match.get("dire_name"), dire_id, id_to_name, aliases)
        if radiant is None or dire is None or radiant == dire:
            continue

        if radiant_id in id_to_logo:
            canonical_logos.setdefault(radiant, id_to_logo[radiant_id])
        if dire_id in id_to_logo:
            canonical_logos.setdefault(dire, id_to_logo[dire_id])

        start_time = int(match.get("start_time") or 0)
        series_id = int(match.get("series_id") or 0)
        series_type = int(match.get("series_type") or 1)
        if series_id:
            key = f"series-{series_id}"
        else:
            pair = "-".join(sorted((normalize(radiant), normalize(dire))))
            key = f"fallback-{pair}-{start_time // 21600}"

        group = grouped.setdefault(
            key,
            {
                "id": key,
                "teamA": radiant,
                "teamB": dire,
                "scoreA": 0,
                "scoreB": 0,
                "maps": [],
                "startedAtEpoch": start_time,
                "requiredWins": required_series_wins(series_type, series_id),
            },
        )
        group["startedAtEpoch"] = min(group["startedAtEpoch"], start_time)
        group["maps"].append(int(match.get("match_id") or 0))

        radiant_won = bool(match.get("radiant_win"))
        if radiant == group["teamA"]:
            if radiant_won:
                group["scoreA"] += 1
            else:
                group["scoreB"] += 1
        else:
            if radiant_won:
                group["scoreB"] += 1
            else:
                group["scoreA"] += 1

    completed_groups = sorted(grouped.values(), key=lambda item: item["startedAtEpoch"])
    state: dict[str, dict[str, Any]] = {
        str(team["name"]): {
            "seriesWins": 0,
            "seriesLosses": 0,
            "mapWins": 0,
            "mapLosses": 0,
            "swissPlayed": 0,
            "actual": "Pending",
            "lastMatchAt": None,
        }
        for team in config
    }

    series_output: list[dict[str, Any]] = []
    for group in completed_groups:
        score_a = int(group["scoreA"])
        score_b = int(group["scoreB"])
        required = int(group["requiredWins"])
        completed = max(score_a, score_b) >= required
        winner = group["teamA"] if score_a > score_b else group["teamB"] if score_b > score_a else ""
        started_at = datetime.fromtimestamp(group["startedAtEpoch"], tz=timezone.utc).replace(microsecond=0)
        started_iso = started_at.isoformat().replace("+00:00", "Z")

        team_a = state[group["teamA"]]
        team_b = state[group["teamB"]]
        team_a["lastMatchAt"] = started_iso
        team_b["lastMatchAt"] = started_iso

        is_swiss = (
            team_a["swissPlayed"] < 5
            and team_b["swissPlayed"] < 5
            and team_a["actual"] == "Pending"
            and team_b["actual"] == "Pending"
        )
        stage = "Swiss" if is_swiss else "Elimination"

        if completed:
            team_a["mapWins"] += score_a
            team_a["mapLosses"] += score_b
            team_b["mapWins"] += score_b
            team_b["mapLosses"] += score_a

            if is_swiss:
                team_a["swissPlayed"] += 1
                team_b["swissPlayed"] += 1
                if winner == group["teamA"]:
                    team_a["seriesWins"] += 1
                    team_b["seriesLosses"] += 1
                else:
                    team_b["seriesWins"] += 1
                    team_a["seriesLosses"] += 1

                for team_state in (team_a, team_b):
                    wins = int(team_state["seriesWins"])
                    losses = int(team_state["seriesLosses"])
                    if wins == 4 and losses == 0:
                        team_state["actual"] = "4-0"
                    elif wins == 4 and losses == 1:
                        team_state["actual"] = "4-1"
                    elif losses == 4 and wins == 0:
                        team_state["actual"] = "0-4"
                    elif losses == 4 and wins == 1:
                        team_state["actual"] = "1-4"
            elif winner:
                loser = group["teamB"] if winner == group["teamA"] else group["teamA"]
                if state[winner]["actual"] == "Pending":
                    state[winner]["actual"] = "Elimination Winner"
                if state[loser]["actual"] == "Pending":
                    state[loser]["actual"] = "Elimination Loser"

        series_output.append(
            {
                "id": group["id"],
                "teamA": group["teamA"],
                "teamB": group["teamB"],
                "scoreA": score_a,
                "scoreB": score_b,
                "winner": winner if completed else "",
                "stage": stage,
                "completed": completed,
                "startedAt": started_iso,
                "matchIds": group["maps"],
            }
        )

    teams_output = []
    config_by_name = {str(item["name"]): item for item in config}
    for name, team_state in state.items():
        team_config = config_by_name[name]
        teams_output.append(
            {
                "name": name,
                "clientName": team_config["clientName"],
                "logoUrl": canonical_logos.get(name) or normalize_logo_url(team_config.get("logoUrl")),
                "seriesWins": team_state["seriesWins"],
                "seriesLosses": team_state["seriesLosses"],
                "mapWins": team_state["mapWins"],
                "mapLosses": team_state["mapLosses"],
                "actual": team_state["actual"],
                "lastMatchAt": team_state["lastMatchAt"],
            }
        )

    completed_count = sum(1 for item in series_output if item["completed"])
    payload = {
        "schemaVersion": 3,
        "status": "live" if completed_count else "ready",
        "source": "OpenDota",
        "message": (
            f"Synced {completed_count} completed series from OpenDota."
            if completed_count
            else "The event league was found; waiting for completed matches."
        ),
        "generatedAt": None,
        "leagueName": league_name,
        "leagueId": league_id,
        "teams": teams_output,
        "series": series_output,
    }
    write_if_changed(payload)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # preserve the last good feed on transient failure
        print(f"sync failed: {error}", file=sys.stderr)
        raise
