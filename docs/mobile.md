# Mobile Deployment Notes

The mobile app is implemented in `mobile/` with Expo React Native. It does not embed the backend or database. The expected runtime is:

```text
Android APK -> Tailscale -> FastAPI backend -> PostgreSQL
```

Use Tailscale for personal remote access instead of exposing the API publicly. If you later move to a public domain, switch the app server URL from `http://...:8000` to `https://...` and remove the need for Android cleartext traffic.

Native reminder notifications are local Android schedules. They are synchronized from backend pending reminders when the app saves events/routines or when the user taps "Senkronize et" in Ayarlar.
