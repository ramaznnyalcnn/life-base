# LifeBase Android architecture

The Android client in `mobile/` is a Flutter 3.38 application for Android 8.0+
(`minSdk 26`). It replaces the previous Expo client in place.

## Product flow

- Five independent modules behind a floating "liquid glass" tab bar, in the
  order **Cüzdan · Takvim · Bugün · İlaç · Notlar**. Bugün is home: the app
  opens there and back returns there. Every tab shows its icon and label; a
  lens springs behind the active one, and sliding a finger along the bar
  switches tabs. Account and settings open from
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

## Medications

- Today's doses in time order (pending, taken, snoozed, skipped, missed after
  two hours), as-needed medicines with a "Şimdi aldım" button, a seven-day
  adherence strip, and the medicine list with stock and a low-stock warning.
- Each medicine: form, dose amount and unit, schedule (N times a day, chosen
  weekdays, every N days, every N hours, or as needed — no alarm), course
  start/end, meal relation, notes, stock with an alert threshold, and alarm
  settings (full screen, snooze length, repeat interval and count).
- Detail page: refill stock, finish a course (it ends yesterday, so nothing
  after counts as missed) or restart it from today, and the last 14 days of
  doses; tapping one corrects it (take, skip, or undo back to unanswered).
- Taking a dose uses stock; undoing returns it. Dose logs are keyed
  `<medicationId>@<UTC time>`, so two devices answering the same dose merge.

**Alarms.** Doses ring on the `meds_alarm` channel with the alarm sound and
alarm volume, keep ringing until answered (up to three minutes), and repeat
every few minutes while unanswered. The notification has Aldım / Ertele / Atla
buttons; the full-screen intent opens `/alarm/<doseId>` above the lock screen,
and when the app is already open the page opens in-app at the ring time
(Android shows neither the full-screen alert nor always a heads-up then).
Only that page may show over the lock screen: the activity turns
`showWhenLocked` off as soon as it closes or a button answers. Answering a
dose anywhere (alarm, list, another device after sync) cancels its remaining
rings and silences one already on screen. Alarms are planned for the next
three days (max 150) and re-planned on every change and on resume.

Settings show the notification, exact-alarm and full-screen (Android 14+)
grants with shortcuts to the system screens; the İlaç screen shows a banner
when one that its medicines need is off. When the exact-alarm grant changes,
every reminder is scheduled again in the new mode.

## Wallet

The wallet is server-authoritative (two people can share it) but works
offline. The phone keeps a mirror of what the server last sent (Drift
`wallet_*` tables, money in kuruş) and an outbox of writes; the screen shows
the mirror with queued writes applied on top, so a new expense or account
appears at once, faded with a clock icon, and balances read "tahmini" until
the server confirms.

- **Screen:** Hepsi / Kişisel / Ortak filter (when something is shared), net
  worth, card debt and this month's spending, a card carousel at real card
  proportions (bank, network, last four digits, this period's spending,
  available limit, statement and due date, a ring counting down to the
  statement date), bank and cash accounts (IBAN copy) and movements by day
  with who entered them on shared accounts.
- **Adding:** the floating button opens the wallet's own flow — Gider, Gelir,
  Transfer or Kart ödemesi — with a big keypad, then account, category chips,
  date and time, "Neden?" (with this category's recent reasons) and, for card
  purchases, installments (equal parts in kuruş over the coming statements).
  Card payments suggest the statement amount and the total debt.
- **Accounts and cards:** type, name, bank, current balance (or debt; history
  is kept by moving the opening balance), limit, statement and due day, last
  four digits, network, colour, IBAN, shared or personal, archive.
- **Card page:** statements with their period, due date, spending, payments
  and status (açık, ödenmedi, kısmen, ödendi, gecikti). A statement counts as
  paid once card payments after its statement date cover it; it can also be
  marked paid/unpaid by hand.
- **Household** (Hesap ve ayarlar → Hane): members, invite code, join with a
  code, leave.

**Sync.** Writes go oldest first, but only writes on the same account wait for
each other: a conflict, failure or retry delay holds just those accounts.
Offline backs off exponentially (5 s … 30 min). A 409 shows "Seninki /
Sunucudaki" (on the movement and in "Kararını bekleyenler"); other refusals
can be retried or dropped. Accepted writes leave the outbox only together with
the pull that contains them, so nothing is counted twice. Pulls run with the
rest of sync; joining or leaving a household replaces the mirror.

## Notes

Notes and checklists live on the device and are backed up like calendar
events (`local_notes`, `local_note_items`; each checklist line is its own
document). The editor saves as you type; an empty new note is never stored.

- **Takvime ekle.** When a note mentions a date or time, a chip offers to add
  it to the calendar (e.g. "Takvime ekle: Yarın 15:00"). Recognition is a fixed
  set of Turkish rules (`core/notes/date_hint.dart`, no AI, offline): bugün,
  yarın, öbür gün, "N gün sonra", haftaya, weekday names (with "haftaya" and
  suffixes like "cuma'ya"), "12 ekim [2027]", "12/10[/2026]", "12.10.2026",
  "15:00", "15.30", "saat 3'te" (afternoon), "sabah 9", "akşam 8", "gece 11",
  "öğlen". "12.10" alone is read as a time. One tap makes the event (title
  without the date words, the note's text as its notes, the default
  reminders) and links it; later edits to the note update the event's text.
  The note shows "Takvimde: …" with options to unlink or delete the event.
- **Lists:** add, tick, drag to reorder, delete; ticked lines move below.
  A note turns into a list (lines become items) and back.
- Search, filters (Tümü / Listeler / Takvimde), pinning and colours.

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
