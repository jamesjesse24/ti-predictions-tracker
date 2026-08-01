# Option B — Team Branding and Logo Integration

This guide wires `lib/team_branding.dart` and `lib/team_logo_service.dart` into the existing tracker. It keeps the user-facing aliases (`TEAM VISION`, `BOOMBOYS`, `IRON WING`, `HULIGANI`) while resolving canonical OpenDota names internally.

## 1. Controller integration

Add these imports to `tracker_controller.dart`:

```dart
import 'team_branding.dart';
import 'team_logo_service.dart';
```

Add the logo service to the constructor and fields:

```dart
TrackerController(
  this.teams, {
  SharedPreferences? preferences,
  LiveResultsService? service,
  NotificationService? notifications,
  TeamLogoService? logoService,
})  : _preferences = preferences,
      _service = service ?? LiveResultsService(),
      _notifications = notifications ?? NotificationService(),
      _logoService = logoService ?? TeamLogoService();

final TeamLogoService _logoService;
```

Add a cache key:

```dart
const _teamLogoCacheKey = 'ti_team_logo_cache_v1';
```

Add this method to `TrackerController`:

```dart
Future<void> hydrateTeamLogos({bool force = false}) async {
  final missing = teams.where(
    (team) => team.logoUrl == null || team.logoUrl!.trim().isEmpty,
  );
  if (!force && missing.isEmpty) return;

  final cachedRaw = _preferences?.getString(_teamLogoCacheKey);
  if (cachedRaw != null && !force) {
    try {
      final cached = Map<String, dynamic>.from(jsonDecode(cachedRaw));
      for (final team in teams) {
        final brand = teamBrandFor(team.name, alternateName: team.clientName);
        final url = cached[brand.canonicalName] as String?;
        if (url != null && url.isNotEmpty) team.logoUrl = url;
      }
      notifyListeners();
    } catch (_) {
      // Invalid cache is ignored and replaced by a fresh response.
    }
  }

  if (teams.every((team) => team.logoUrl?.isNotEmpty == true) && !force) return;

  try {
    final discovered = await _logoService.discoverLogos();
    for (final team in teams) {
      final brand = teamBrandFor(team.name, alternateName: team.clientName);
      final url = discovered[brand.canonicalName];
      if (url != null && url.isNotEmpty) team.logoUrl = url;
    }
    await _preferences?.setString(_teamLogoCacheKey, jsonEncode(discovered));
    await _save();
  } catch (_) {
    // Logo loading is visual-only and must never break results sync.
  }
}
```

Call it after the normal feed is applied:

```dart
_applyFeed(feed);
await hydrateTeamLogos();
await _notifications.notifyForNewSeries(feed.series);
```

Close the service:

```dart
@override
void dispose() {
  _logoService.close();
  _service.close();
  super.dispose();
}
```

## 2. Replace monogram-only widgets

Import the branding module in `main.dart` and `group_stage_status_panel.dart`:

```dart
import 'team_branding.dart';
```

### Prediction card

Replace:

```dart
_Monogram(text: team.initials, size: 48)
```

with:

```dart
TeamLogo(
  name: team.name,
  alternateName: team.clientName,
  logoUrl: team.logoUrl,
  size: 52,
)
```

Use the team colour for the card edge:

```dart
final brand = teamBrandFor(team.name, alternateName: team.clientName);

TeamAccentCard(
  name: team.name,
  alternateName: team.clientName,
  padding: EdgeInsets.zero,
  child: ...,
)
```

### Fantasy card

Replace its monogram with:

```dart
TeamLogo(
  name: team.name,
  alternateName: displayTeam,
  logoUrl: team.logoUrl,
  size: 56,
)
```

Use the team brand colour as the secondary accent while retaining the role colour for `CORE`, `MID`, or `SUPPORT`:

```dart
final brand = teamBrandFor(team.name, alternateName: displayTeam);
```

Recommended hierarchy:

- role chip: role colour
- team card border/glow: team colour
- fantasy percentages: role colour
- team logo tile: team colour

### Field snapshot

Replace:

```dart
_Monogram(text: team.initials, size: 34)
```

with:

```dart
TeamLogo(
  name: team.name,
  alternateName: team.clientName,
  logoUrl: team.logoUrl,
  size: 38,
  showGlow: false,
)
```

### Completed series

Use both team identities:

```dart
TeamLogo(
  name: first?.name ?? series.teamA,
  alternateName: first?.clientName,
  logoUrl: first?.logoUrl,
  size: 40,
  showGlow: false,
)
```

Repeat for the opponent.

### Group-stage standings

Replace `_StageTeamLogo` with the shared widget:

```dart
TeamLogo(
  name: team.name,
  alternateName: team.clientName,
  logoUrl: team.logoUrl,
  size: 38,
  showGlow: false,
)
```

Delete the duplicate logo/monogram implementation from the group-stage file.

## 3. App start behavior

Keep application startup non-blocking:

```dart
runApp(TrackerApp(controller: controller));
unawaited(controller.hydrateTeamLogos());
unawaited(_initializeOptionalServices(controller));
```

The interface appears immediately. Logos populate after cache or network resolution without delaying `runApp()`.

## 4. Feed-side improvement

The GitHub synchronization script should also query `/teams` when the event league team list lacks `logo_url`. Match each returned `name` and `tag` against the aliases in `data/teams.json`, then write the resolved URL into `data/live.json`.

The priority order is:

1. logo URL supplied by the current league feed
2. globally discovered OpenDota team logo
3. cached logo URL on the device
4. team-coloured monogram fallback

## 5. Verification checklist

- Real logos appear on Predictions, Fantasy, Overview snapshots, completed series, and standings.
- A failed image request shows the correct team-coloured monogram.
- Logo loading never blocks startup or results synchronization.
- User-facing aliases stay unchanged.
- `TEAM VISION` resolves to `PARIVISION`.
- `BOOMBOYS` resolves to `BetBoom Team`.
- `IRON WING` resolves through its configured real-team aliases.
- `HULIGANI` resolves through its configured `L1ga` aliases.
- Cached logos remain visible offline after the first successful resolution.
