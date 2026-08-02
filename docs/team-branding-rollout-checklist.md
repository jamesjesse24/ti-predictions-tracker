# Team Branding Rollout Checklist

Use this checklist when applying the Option B module to the current UI.

## Phase 1 — logo plumbing

- [ ] Import `team_branding.dart` in `main.dart` and `group_stage_status_panel.dart`.
- [ ] Add `TeamLogoService` to `TrackerController`.
- [ ] Load cached logos before the first network request.
- [ ] Resolve missing logos after every successful results synchronization.
- [ ] Persist resolved URLs in SharedPreferences.
- [ ] Keep logo loading outside the critical startup path.

## Phase 2 — screen replacement

- [ ] Replace prediction monograms with `TeamLogo`.
- [ ] Replace fantasy monograms with `TeamLogo`.
- [ ] Replace overview snapshot monograms with `TeamLogo`.
- [ ] Replace completed-series monograms with `TeamLogo`.
- [ ] Replace group-stage standings monograms with `TeamLogo`.
- [ ] Wrap team-focused cards with `TeamAccentCard`.

## Phase 3 — visual polish

- [ ] Use team colour for card edge/glow.
- [ ] Preserve semantic green/red/blue for results and status.
- [ ] Keep role colours for fantasy values.
- [ ] Add `Refresh team logos` and `Clear logo cache` rows to Control.
- [ ] Verify all aliases against the OpenDota response.

## Phase 4 — release validation

- [ ] Flutter analysis passes.
- [ ] Widget tests pass.
- [ ] Release APK builds.
- [ ] Real logos appear after first successful internet connection.
- [ ] Offline mode displays cached logos or branded fallbacks.
- [ ] No logo failure can interrupt live results synchronization.
