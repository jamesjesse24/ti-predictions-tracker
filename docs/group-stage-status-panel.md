# Group Stage Status Panel

The dashboard now includes a live group-stage status panel derived from the synchronized team and series data.

It shows:

- current stage state: waiting, in progress, or complete
- final-outcome progress across all 16 teams
- direct qualifiers (`4-0` and `4-1`)
- elimination/play-in winners
- active teams still in play
- eliminated teams
- completed Swiss-series count
- an expandable standings table ordered by outcome, series record, losses, map differential, and team name
- team logos with initial-based fallbacks

No separate static standings dataset is used. The panel updates from the same live feed and offline cache as the rest of the app.
