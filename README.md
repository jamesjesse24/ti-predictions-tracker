# TI Predictions Tracker

A polished Flutter app for tracking The International 2026 group-stage selections, automatic tournament results, comparison accuracy, and a fantasy roster.

## Features

- Preloaded 16-team TI selection board
- Automatic result synchronization from OpenDota
- GitHub Actions feed refresh every 15 minutes
- App refresh on launch, pull-to-refresh, and every five minutes while open
- Offline cache using `shared_preferences`
- Series and map records for all teams
- Automatic terminal-category classification
- Exact selection-vs-result comparison
- Accuracy dashboard and recent completed-series feed
- Manual fallback controls when remote data are unavailable
- Fantasy roster and crafted-banner overview
- JSON export/import for backups
- Dark gold esports-inspired interface
- Automated APK builds and GitHub Releases

## Automatic data flow

The installed APK does **not** need to be rebuilt when a match finishes.

1. `.github/workflows/sync-results.yml` runs every 15 minutes.
2. `scripts/sync_results.py` discovers the TI 2026 OpenDota league, downloads league matches and teams, resolves client aliases, and calculates series/map records.
3. The workflow commits only meaningful changes to `data/live.json`.
4. The APK reads the raw `data/live.json` file and stores the latest successful result locally.
5. `android.yml` ignores data-only commits so an APK rebuild is not triggered for every match.

Before OpenDota publishes the event league, the feed remains in a visible `waiting` state. The workflow discovers the league automatically. `OPENDOTA_LEAGUE_ID` can be supplied during a manual workflow run to override discovery.

An optional `OPENDOTA_API_KEY` repository secret is supported but not required for normal low-frequency updates.

## Local development

Install Flutter 3.44.7 or a compatible release, then run:

```bash
flutter create . --platforms=android --org com.jamesjesse24 --project-name ti_predictions_tracker
flutter pub get
flutter run
```

The Android platform directory is generated rather than committed, keeping the repository small and allowing CI to recreate it consistently.

To test the result generator locally:

```bash
python scripts/sync_results.py
```

To force a known league:

```bash
OPENDOTA_LEAGUE_ID=12345 python scripts/sync_results.py
```

## APK builds

Every application-code push to `main`, pull request, or manual Android workflow run builds an installable APK and uploads it as a GitHub Actions artifact. Changes limited to `data/live.json` are excluded from APK builds.

To publish a versioned APK:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The workflow creates the GitHub Release and attaches the generated APK. The continuous `latest` release is refreshed after successful application builds on `main`.

> The current workflow uses Flutter's generated development signing configuration for direct installation and testing. Configure a permanent private Android signing key through encrypted GitHub Actions secrets before app-store distribution.

## Data sources and limitations

The result feed uses OpenDota league metadata and match records. Team aliases are defined in `data/teams.json`. The script preserves the last successful feed if a network or API error occurs. Elimination winners and losers are inferred only after a completed post-Swiss series is available.

The app is a tournament-results and selection-comparison tool. It does not include wagering, payment, or prize functionality.

## License

MIT
