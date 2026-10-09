# LifeBase Android architecture

The Android client in `mobile/` is a Flutter 3.38 application for Android 8.0+
(`minSdk 26`). It replaces the previous Expo client in place.

## Product flow

- Four independent modules behind a floating glass navigation bar:
  **Bugün**, **Cüzdan**, **Takvim**, **İlaç**. Account and settings open from
  the profile button in each module's header.
- Each module owns its add flow (floating add button → container transform
  into that module's own page). There is no shared "Ekle" wizard.
- Each tab keeps its own navigation stack (`StatefulShellRoute`). Android back
  pops inside the current tab first, then returns to Bugün, and on Bugün asks
  for a second press before leaving the app. Add pages with unsaved input ask
  before discarding.
- Neumorphic surfaces with four colour schemes (Kum, Adaçayı, Okyanus, Gece),
  light/dark/system mode and a reduce-motion switch, all persisted.
  Transitions: fade-through between tabs, shared-axis inside a tab.

## Layers

```text
lib/
  core/
    design_system/  tokens, theme, neumorphic surfaces, glass bar, transitions
    models/         API-facing immutable values
    network/        Dio client
    storage/        Drift cache and operation queue
    sync/           FIFO retry/conflict policy
    platform/       Flutter ↔ Android method channel
    routes.dart     route paths shared by shell and modules
  modules/
    today/ wallet/ calendar/ meds/ account/   each with ui/ and data/
  shell/            router and the glass-bar shell
android/
  CredentialVault.kt   Android Keystore-backed worker credentials
  CalendarSyncer.kt    Calendar Provider rolling-window projection
  SyncWorker.kt        15-minute and immediate background work
  widget/              responsive Jetpack Glance widget and quick action
```

Modules never import one another; they share `core/` and navigate by route
path. `test/architecture_test.dart` enforces this.

## Offline and conflict behavior

**Calendar and medications are local-first.** They live in Drift tables
(`local_events`, `local_medications`, `local_dose_logs`) and are backed up to
`/api/v3/sync` as opaque JSON documents:

- every write stamps the row (milliseconds, always moving forward) and marks
  it dirty; the sync engine pushes dirty rows, then pulls by cursor;
- the newest write wins; deletions are final and never resurrected by a stale
  device; an edit made while a push is in flight stays dirty;
- sync runs at start, when the network returns, on resume and two seconds
  after an edit. Signing out clears this account's local rows (after warning
  about anything not yet backed up).

**Other data (tasks, wallet, server agenda)** still uses the operation queue:
every mutation is stored first as an operation envelope with a UUID, then sent
FIFO (5xx/network: retry; 401: pause; 409: keep the server snapshot for a
decision; other 4xx: mark failed).

## Calendar

- Month grid with colour dots, week strip and 24-hour day timeline; LifeBase
  and Google events side by side (filterable).
- Events: title, notes, all-day, start/end, colour, importance, repetition
  (daily/weekly with weekdays/monthly/yearly, every N, until a date) and any
  number of reminders (offset or fixed time, normal or high priority). New
  events start with the default reminder set from settings.
- Editing or deleting a repeating event asks: only this, this and following,
  or the whole series.
- Reminders are scheduled locally with `flutter_local_notifications` for the
  next 14 days (max 300) and re-planned whenever events change or the app
  resumes; they fire offline and survive reboots. Without the exact-alarm
  grant (settings) Android may deliver them a few minutes late.
- Server-side events and routines are imported on-device once.

## Android integration

**Google calendar, both ways, own account only.** Settings connect the
phone's Google account. LifeBase reads events from calendars that account
owns (holiday, birthday, shared/group calendars and other accounts are
excluded) and writes its own events into the account's primary calendar: one
provider event per LifeBase event, repeating ones as `RRULE`/`EXDATE`, without
copying reminders (LifeBase notifies itself). Projected events are never read
back.

`CalendarSyncer` still projects the remaining server agenda kinds (tasks,
medication doses, payments) and feeds the widget; WorkManager runs it every 15
minutes and after a widget action.

The Glance widget scales with launcher space and shows the next item and open
count. Its quick button completes the first task or records the first medication
dose with a fresh UUID; all other detail work opens in the app.

## Development connectivity

The expected personal deployment path is:

```text
Flutter Android APK -> Tailscale -> FastAPI backend -> PostgreSQL
```

Use Tailscale for remote access instead of exposing the API publicly. During
USB development, `adb reverse tcp:8000 tcp:8000` lets the app connect to
`http://localhost:8000`. A public deployment should use an HTTPS API URL.

## Verification

```bash
cd mobile
flutter pub get
dart run build_runner build --force-jit
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
