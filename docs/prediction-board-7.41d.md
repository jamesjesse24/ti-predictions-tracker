# TI 2026 final prediction board — post-7.41d model

Updated: 2026-08-03 15:31 Asia/Manila

## Status

This replaces the provisional 1.4.1+10 board. The update is based on a full post-7.41d game-by-game dataset rather than tournament placements alone.

The in-client distribution remains fixed at one 4-0 team, two 4-1 teams, five elimination-round winners, five elimination-round losers, two 1-4 teams, and one 0-4 team.

## Final board

| Prediction | Teams |
|---|---|
| 4-0 | PARIVISION |
| 4-1 | Team Yandex; BetBoom Team |
| Elimination Winner | Team Falcons; Team Spirit; Vici Gaming; Team Liquid; Team Resilience |
| Elimination Loser | Nigma Galaxy; Aurora Gaming; LGD Gaming; IRON WING / 1w; OG |
| 1-4 | Xtreme Gaming; GamerLegion |
| 0-4 | HULIGANI / L1 Team |

## Changes from 1.4.1+10

- Nigma Galaxy: Elimination Winner → Elimination Loser
- Team Liquid: Elimination Loser → Elimination Winner
- IRON WING / 1w: Elimination Winner → Elimination Loser
- Team Resilience: Elimination Loser → Elimination Winner
- Xtreme Gaming: Elimination Loser → 1-4
- OG: 1-4 → Elimination Loser

Aurora Gaming remains an Elimination Loser, but the analysis no longer supports placing 1w above Aurora. Aurora ranked eighth to ninth across the sensitivity profiles, while 1w ranked tenth to twelfth. Both remain in the same elimination-loser bucket because neither had a stable winner-slot advantage.

## Dataset and quality controls

- Analysis window: patch 7.41d release on 2026-06-04 through 2026-08-03 07:31 UTC.
- 316 unique maps were requested from OpenDota; 315 were fetched successfully.
- Three unrelated amateur maps from a different team using the name `BoomBoys` were detected and removed from BetBoom Team.
- Final cleaned dataset: 312 unique maps and 439 team-perspective records.
- Parsed economy, draft, objective, player, and team-fight telemetry was available for the cleaned maps.
- One Falcons-versus-1w map was unavailable after an HTTP 429 response. The available map was retained, but the incomplete series was excluded from series-rate calculations.
- Current-roster overlap was measured map by map. Matches involving a recent substitute or previous roster were downweighted.

## Transparent weighted model

| Component | Weight |
|---|---:|
| Opponent-adjusted Elo | 25% |
| Tier-1 LAN form | 15% |
| Weighted map form | 12% |
| Recent form | 8% |
| Swiss and best-of-three stability | 15% |
| Results against the 16-team TI field | 10% |
| Economy, objectives, and team-fight execution | 8% |
| Draft and hero-pool breadth | 4% |
| Current-roster continuity | 3% |

Five sensitivity profiles were evaluated: baseline, LAN-heavy, recent-heavy, Swiss-heavy, and opponent-heavy. The tournament model then ran 100,000 Swiss-format simulations across those profiles. Simulations alternated seeded and randomized pairing assumptions because the exact TI 2026 first-round pairings were not available at the cutoff.

## Robust ranking

| Rank | Team | Robust score | Rank range |
|---:|---|---:|---:|
| 1 | PARIVISION | 76.5 | 1–1 |
| 2 | Team Yandex | 72.2 | 2–2 |
| 3 | Team Spirit | 60.5 | 3–4 |
| 4 | BetBoom Team | 60.4 | 3–5 |
| 5 | Vici Gaming | 57.0 | 4–6 |
| 6 | Team Falcons | 56.2 | 5–7 |
| 7 | Team Resilience | 54.7 | 6–7 |
| 8 | Team Liquid | 50.2 | 8–9 |
| 9 | Aurora Gaming | 49.3 | 8–9 |
| 10 | OG | 47.4 | 10–13 |
| 11 | IRON WING / 1w | 47.4 | 10–12 |
| 12 | LGD Gaming | 47.1 | 10–12 |
| 13 | Nigma Galaxy | 44.8 | 11–14 |
| 14 | Xtreme Gaming | 41.4 | 13–14 |
| 15 | GamerLegion | 37.2 | 15–15 |
| 16 | HULIGANI / L1 Team | 28.0 | 16–16 |

BetBoom and Team Spirit were effectively tied near the 4-1 boundary. BetBoom retained the 4-1 slot because it held that slot in three of the five profile-specific constrained boards and had substantially stronger evidence coverage.

## Aurora Gaming versus IRON WING / 1w

There was no direct post-7.41d head-to-head series in the dataset.

1w held a small advantage in opponent-adjusted Elo and Tier-1 LAN map rate. Aurora held the stronger recent rate, TI-field rate, best-of-three stability, execution score, draft breadth, and simulated elimination-winner frequency. The resulting composite advantage for Aurora was narrow but consistent enough to reject the provisional assumption that 1w should be placed one full bucket above Aurora.

## Main uncertainty

Team Resilience is the highest-risk winner-slot selection. It was assigned Elimination Winner in all five sensitivity boards, but its evidence confidence was the lowest in the field because it had no post-patch Tier-1 LAN maps in the dataset. Its strong qualifier run, recent series performance, and execution metrics support the pick, but the confidence label should remain lower than for established LAN teams.

## Sources

- OpenDota API match, player, draft, objective, team-fight, and economy data
- Valve / Dota 2 patch 7.41d notes
- Liquipedia tournament formats, schedules, results, and roster records
- Official TI format description for the five-round best-of-three Swiss stage and elimination round

These are competitive forecasts for the TI prediction board, not guarantees. Results after the fixed cutoff are intentionally excluded and should trigger a new review before another prediction migration.
