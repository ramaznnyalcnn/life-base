# LifeBase Mobile

Expo React Native Android app for the existing LifeBase FastAPI backend.

## Topology

- Backend stays on the always-on second computer.
- Android connects through Tailscale, for example `http://lifeos:8000`.
- The mobile app stores the server URL in-app, then calls `/api/v1/*`.
- Login tokens are stored with `expo-secure-store`.
- Reminder notifications are Android local notifications scheduled from `/events/dashboard`.

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

```bash
cd mobile
npm install
npm run verify:config
npm run typecheck
npm run start
```

Open the app in Expo Go or run a native Android build:

```bash
npm run android
```

## APK Build

Cloud EAS APK:

```bash
cd mobile
npm install -g eas-cli
npm run build:apk
```

Local EAS APK:

```bash
cd mobile
npm run build:local-apk
```

The preview profile outputs an installable APK for personal Android use.

## Current Scope

- Cuzdan: net worth, monthly income/expense, card/account overview.
- Yonet: account/card create, edit and active/passive state.
- Ekle: transaction, event, routine and AI command entry.
- Gecmis: transaction list, filters, edit and delete.
- Takvim: month view, upcoming events, edit/complete/delete.
- Ayarlar: server URL, theme, logout, health, notification test and reminder sync.
