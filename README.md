# TI Predictions Tracker

A polished, offline-first Flutter app for tracking The International group-stage predictions, actual team records, prediction accuracy, and a fantasy roster.

## Features

- Preloaded 16-team TI prediction board
- Live manual Swiss-stage win/loss tracking
- Exact prediction-vs-result comparison
- Accuracy dashboard and miss analysis
- Fantasy roster and banner overview
- Local persistence on Android
- JSON export/import for backups
- Dark gold esports-inspired interface
- GitHub Actions APK builds
- Automatic GitHub Release attachment for `v*` tags

## Local development

Install Flutter 3.44.7 or a compatible stable release, then run:

```bash
flutter create . --platforms=android --org com.jamesjesse24 --project-name ti_predictions_tracker
flutter pub get
flutter run
```

The Android platform directory is generated rather than committed, keeping the repository small and allowing the CI workflow to recreate it consistently.

## APK builds

Every push to `main`, pull request, or manual workflow run builds an installable APK and uploads it as a GitHub Actions artifact.

To publish an APK on the GitHub Releases page:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow creates the release automatically and attaches `ti-predictions-tracker-v1.0.0.apk`.

> The initial workflow uses Flutter's generated development signing configuration for sideload testing. Before distributing through an app store, configure a permanent private Android signing key through GitHub Actions secrets.

## Data model

Predictions are stored locally with `shared_preferences`. No account, server, or API key is required. The app supports JSON export/import so records can be backed up or transferred.

## License

MIT
