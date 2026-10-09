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

The last successful daily agenda is cached in Drift. Every mutation is stored
first as an operation envelope with a UUID, then sent FIFO:

- network failure or HTTP 5xx: keep pending and retry;
- HTTP 401: pause the queue until the user signs in again;
- HTTP 409: retain the server snapshot for a user conflict decision;
- other validation errors: mark failed instead of retrying forever.

Planning completion is reflected after the next cached agenda refresh. Finance
operations never alter a local balance before the server confirms them.

## Android integration

The user chooses a writable Google or device calendar. `CalendarSyncer` projects
the `-30/+180` day agenda in API-safe chunks, keeps stable source mappings,
prefixes completed records with `✓`, copies reminders, and removes deleted
records. WorkManager runs every 15 minutes and immediately after calendar
selection or a widget action.

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
