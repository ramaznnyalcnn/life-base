# Mobile Deployment Notes

The mobile app is implemented in `mobile/` with Flutter for Android. It does not embed the backend or PostgreSQL database. The expected runtime is:

```text
Flutter Android APK -> Tailscale or USB forwarding -> FastAPI backend -> PostgreSQL
```

Use Tailscale for personal remote access instead of exposing the API publicly. For USB development, `adb reverse tcp:8000 tcp:8000` lets the app connect to `http://localhost:8000`. If you later move to a public domain, switch the app server URL to HTTPS.

Native reminders, Android Calendar Provider synchronization, background work, encrypted credentials, offline operations, and the Glance widget are documented in [Android architecture](mobile-android.md).
