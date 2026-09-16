# LifeBase Android architecture

The Android client in `mobile/` is a Flutter 3.38 application for Android 8.0+
(`minSdk 26`). It replaces the previous Expo client in place.

## Product flow

- Five destinations: **Bugün**, **Takvim**, **Ekle**, **Finans**, **Sağlık**.
- Domain actions start from the full-screen **Ekle** wizard. The wizard reads
  `/api/v2/operations/catalog` and `/context`, so choices remain server-driven.
- Free text is limited to short names and titles. Money and dosage use numeric
  inputs; dates, times, categories, accounts, recurrence and reminders use
  pickers or chips.
- OLED dark mode is the default. An accessible light theme is available in
  settings; controls use Material 3 and 48dp-or-larger touch targets.

## Layers

```text
lib/
  core/
    models/       API-facing immutable values
    network/      Dio client
    storage/      Drift cache and operation queue
    sync/         FIFO retry/conflict policy
    platform/     Flutter ↔ Android method channel
  features/
    auth/ today/ calendar/ add/ finance/ health/ settings/ shell/
android/
  CredentialVault.kt   Android Keystore-backed worker credentials
  CalendarSyncer.kt    Calendar Provider rolling-window projection
  SyncWorker.kt        15-minute and immediate background work
  widget/              responsive Jetpack Glance widget and quick action
```

Feature screens watch Riverpod providers and keep network/storage/platform work
outside widgets. GoRouter owns top-level navigation.

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
