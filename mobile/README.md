# LifeBase Android

Flutter 3.38 tabanlı, seçim odaklı LifeBase istemcisi.

## Çalıştırma

```bash
flutter pub get
flutter run
```

Uygulama ilk açılışta sunucu adresi ve kullanıcı bilgilerini ister; ardından
takvim ve bildirim izinlerini toplar. Android 8.0+ desteklenir.

## Topology

- Backend stays on the always-on second computer.
- Android connects through Tailscale, for example `http://lifeos:8000`.
- The client uses `/api/v2` structured operations and daily read endpoints.
- Flutter keeps the login token in Android encrypted storage. The native worker
  has a separate Android Keystore-encrypted copy for background sync.
- HTTP is supported for user-selected emulator, LAN, and Tailscale servers;
  use HTTPS for any server reachable from the public internet.

## Server Checklist

On the second computer:

```bash
cd /opt/lifeos
./infra/scripts/backend-migrate.sh
HOST=0.0.0.0 PORT=8000 ./infra/scripts/backend-start.sh
```

For systemd, use the existing files in `infra/systemd/`. The API should answer:

```bash
curl http://127.0.0.1:8000/health
```

Then install Tailscale on the server and Android phone. In the app, set the server URL to the server MagicDNS name or Tailscale IP:

```text
http://lifeos:8000
http://100.x.y.z:8000
```

For personal use, prefer `SINGLE_USER_MODE=false` plus a user created with the backend CLI so the APK uses the login screen.

## Local Development

Android derlemesi için JDK 21 kullanın. `JAVA_HOME` daha yeni ve Gradle ile
uyumsuz bir JDK gösteriyorsa komutu JDK 21 ile çalıştırın.

```bash
cd mobile
flutter pub get
dart run build_runner build --force-jit
flutter analyze
flutter test
JAVA_HOME=/path/to/jdk-21 flutter run
```

## APK Build

```bash
cd mobile
JAVA_HOME=/path/to/jdk-21 flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Configure a
private release signing key before producing a distributable release build.

## Current Scope

- **Bugün:** next item, overdue work, tasks, and hourly timeline.
- **Cüzdan:** overview and account cards; its own add flow.
- **Takvim:** local-first events with month/week/day views, notes, repetition,
  any number of offline reminders, and two-way sync with the user's own Google
  calendar.
- **İlaç:** upcoming doses and medication program; its own add flow.
- **Hesap ve ayarlar** (profile button): colour scheme, light/dark mode,
  reduce motion, queue/conflict status, writable calendar, and logout.

İlaç and Cüzdan add pages are placeholders until their phases land.

The app caches read surfaces with Drift and queues UUID operations FIFO. Native
WorkManager refreshes the selected Android calendar, Glance widget, and local
alarms every 15 minutes and immediately after a mutation.
