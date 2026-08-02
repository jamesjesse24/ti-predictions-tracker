# Option C — Professional UI Redesign Specification

## Product direction

The tracker should feel like a premium tournament operations dashboard, not a generic dark Flutter application. The visual identity combines:

- near-black neutral surfaces
- restrained TI gold for product-level actions
- authentic team colours for team-level content
- real team logos wherever a team is the primary subject
- concise status language
- dense but readable information hierarchy

The design must avoid oversized explanation blocks, excessive gradients, repeated labels, and decorative elements that do not communicate state.

---

## Design tokens

### Colour system

| Token | Value | Use |
|---|---:|---|
| Background | `#080A0E` | App canvas |
| Surface | `#11141A` | Standard cards |
| Surface raised | `#171B22` | Dialogs, active controls |
| Border | `#282E38` | Neutral card edges |
| Text primary | `#F6F3EE` | Titles and important values |
| Text secondary | `#929AA8` | Metadata and labels |
| Product gold | `#D8A84E` | Navigation, sync, title identity |
| Product gold light | `#FFD98A` | Selected text and highlights |
| Success | `#4ADE80` | Correct, qualified, connected |
| Danger | `#FB7185` | Incorrect, eliminated, destructive |
| Information | `#60A5FA` | Active/in-progress state |

Team colours must come from `team_branding.dart`. Team colour never replaces semantic colours for errors, success, or destructive actions.

### Spacing

Use a 4-point grid.

- screen horizontal padding: `16`
- card-to-card gap: `8–12`
- section gap: `20–24`
- compact card padding: `12–14`
- hero card padding: `16–18`
- bottom content clearance: `96–104`

### Radius

- small controls: `12`
- standard cards: `18`
- feature cards: `22`
- navigation container: `22`
- pills: `999`

### Typography

- page title: 22 px, weight 900
- section title: 17 px, weight 900
- team title: 15–16 px, weight 900
- primary metric: 18–24 px, weight 900
- body/status: 11–13 px
- micro label: 8–10 px, uppercase only for data labels

Avoid paragraphs longer than two lines inside cards.

---

## Global shell

### App bar

- left: app mark, 38 px
- title: one line only
- right: alerts and refresh buttons
- remove all page subtitles
- refresh button animates only while a request is active
- notification icon uses gold only when enabled

### Bottom navigation

- four destinations: Overview, Picks, Fantasy, Control
- selected item uses a restrained gold capsule
- unselected icons remain neutral
- labels remain visible for all destinations
- no badges unless there is a new result or a permission problem

### Background

Use a subtle vertical neutral gradient. Do not use a large texture, illustration, or animated background. Team colour should enter through content cards rather than the entire page.

---

## Overview

### 1. Connection strip

A compact single-row card at the top.

Content:

- cloud/status icon
- state: `CONNECTED`, `WAITING`, or `OFFLINE`
- source: OpenDota
- `Last checked` timestamp
- optional league-ID chip

Do not display the full sync message here. Put detailed feed diagnostics in Control.

### 2. Metrics

Three equal compact cards:

- Accuracy
- Exact hits
- Completed series

Each card contains one icon, one strong value, and one label. Do not add descriptive sentences.

### 3. Group stage

The group-stage panel is the primary information block.

Header:

- title: `Group stage`
- status chip: Waiting / In progress / Complete
- progress percentage and thin progress bar

Summary metrics:

- Direct
- Play-in W
- Active
- Out

Current table:

- rank
- real team logo
- team name
- series record
- map differential
- concise status chip

Waiting state:

- title: `Standings unavailable`
- detail: `Unlocks after the first official series`

### 4. Latest results

Each result card shows:

- logo A
- team A name
- score
- team B name
- logo B
- stage and winner in one secondary line

Use a winner accent, not a large winner paragraph.

Empty state:

- title: `No completed series yet`
- detail: `Waiting for the first synced result`

### 5. Field snapshot

Horizontal compact team cards containing:

- real logo
- team name
- series record
- tiny live dot only when the team has live data

Use team-colour card edges. Do not show secondary canonical names here.

---

## Predictions

### Search and filters

- search field: `Search teams`
- horizontal filter chips
- selected filter uses product gold
- filters use short labels: 4–0, 4–1, Play-in W, Play-in L, 1–4, 0–4

### Prediction card

Header row:

- 52 px real team logo
- user-facing team name
- smaller canonical name only when different
- right-side status: Live / Waiting / Settled

Data row:

- Pick
- Series
- Maps
- Result

Use team colour on the card border and logo area. Use semantic success/danger for prediction correctness.

Manual fallback controls appear only when no live data are available. They must be visually subordinate and contained in a single compact footer row.

Do not show a decorative progress line with no meaningful value.

---

## Fantasy

### Title card

Content:

- app mark
- small prefix: `LET HIM COOK`
- main title: `[LTGS] the Clutch`
- small status: `Group Stage Lineup`

Keep the title card under 110 px high.

### Roster card

Header:

- 56 px real team logo
- role chip
- team name
- player names
- series record

Stat row:

- three equal cells
- icon
- percentage
- short label

Colour rules:

- team border/glow: team brand colour
- role chip and fantasy values: role colour
- neutral card surface: dark

This dual-accent system creates team identity without confusing roles.

Recommended role colours:

- Core: `#FB7185`
- Mid: `#60A5FA`
- Support: `#4ADE80`

---

## Control

The page should look like a professional settings screen.

### Result alerts

One compact card:

- bell icon
- `Result alerts`
- `Checks every 15 min`
- switch

When permission is denied, show a small inline warning below the card—not a large paragraph.

### Synchronization

Rows:

1. `Sync results` — last checked time
2. `Feed status` — source, league ID, and remote feed-updated time
3. `Refresh team logos` — last logo-cache update or unresolved count

Use a spinner in the relevant row only while that task is running.

### Backup

Rows:

- Copy backup
- Import backup

### Local data

Rows:

- Clear logo cache
- Reset tracker

Destructive rows use danger colour only for their icon/title and confirmation action.

---

## Team identity behavior

### Logo priority

1. logo URL from the live event feed
2. logo resolved from OpenDota's team list
3. cached logo URL from the device
4. team-coloured monogram fallback

### Alias rules

User-facing names remain locked:

- PARIVISION → TEAM VISION
- BetBoom Team → BOOMBOYS
- configured real team → IRON WING
- L1ga alias set → HULIGANI

Canonical names are used only for matching and optional secondary metadata.

### Failure states

- image loading: small progress indicator inside the tile
- image failure: immediate branded monogram
- offline: cached network image or monogram
- logo resolution failure: results synchronization continues normally

Logo resolution is visual-only and must never block app startup, live results, or notifications.

---

## Motion

Use restrained motion only:

- refresh icon rotation while syncing
- 150–220 ms fade when a logo replaces a monogram
- 180 ms colour transition for selected navigation/filter states
- no looping card animations
- no parallax or continuous glow animation

Respect reduced-motion settings where available.

---

## Accessibility

- minimum touch target: 44 × 44 px
- body text contrast: WCAG AA target
- do not encode qualified/eliminated state by colour alone
- logos require semantic labels such as `Team Liquid logo`
- support text scaling without clipping primary records
- all statuses must have readable text labels

---

## Responsive behavior

### Narrow phones

- keep four data cells but reduce label size to 8 px
- allow prediction result values to wrap to two lines
- hide canonical secondary name before reducing the primary team name
- group-stage metrics remain four columns at minimum width 360 px; below that, use two-by-two

### Tablets

- maximum content width: 760 px
- center content
- use two-column layouts only for independent cards, never split the standings table

---

## Acceptance criteria

The redesign is complete when:

- real team logos appear across all team-focused screens after one successful logo resolution
- every logo has a team-coloured fallback
- page subtitles and obvious explanatory paragraphs are removed
- Overview shows connection, metrics, group status, latest results, and field snapshot without scrolling through a large hero
- prediction cards are visually distinct by team without losing semantic correctness colours
- fantasy cards use both team identity and role identity
- Control contains concise settings rows rather than dashboard-style text blocks
- no visual-only service can crash or delay startup
- Flutter analysis and widget tests pass
- the release APK builds through the existing GitHub Actions pipeline
