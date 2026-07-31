# Group Stage Status Panel

The dashboard panel will be derived entirely from the live team records already stored by `TrackerController`.

It will display:

- overall group-stage progress based on completed Swiss series
- qualified teams (`4-0` or `4-1`)
- eliminated teams (`0-4` or `1-4`)
- active teams still playing
- current standings ordered by series wins, series losses, map differential, and team name
- visual team identity using the existing logo/fallback component

The panel remains useful before matches begin by showing a waiting state and zero progress.
