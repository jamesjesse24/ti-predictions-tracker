# Option C release notes

Version 1.4.0 applies the full professional redesign to the running application.

## Visual system

- Team-colour identity across all team-focused cards
- Real OpenDota logos with cached URLs and branded fallbacks
- Compact single-line page headers
- Restrained dark neutral background and product-gold navigation
- Clear semantic colours for success, danger, and active states

## Screens

- Overview: connection strip, metrics, responsive group stage, latest results, field snapshot
- Predictions: logo cards, team accent borders, compact record grid, manual fallback
- Fantasy: dual team/role identity, larger team logos, compact banner stats
- Control: separate result/feed timestamps, logo refresh, cache clearing, backup and reset

## Reliability

- Logo loading runs outside startup-critical code
- Failed logos fall back immediately without affecting results sync
- Logo URLs persist for offline use
- Background notifications and existing results logic remain intact
