const CACHE_NAME = "life-base-shell-v3";
const APP_SHELL = ["/", "/manifest.json", "/icons/icon-192.svg", "/icons/icon-512.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) {
        return cached;
      }

      return fetch(event.request)
        .then((response) => {
          if (!response || response.status !== 200 || response.type !== "basic") {
            return response;
          }

          const cloned = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, cloned));
          return response;
        })
        .catch(() => caches.match("/"));
    })
  );
});

self.addEventListener("push", (event) => {
  const payload = event.data ? event.data.json() : {};
  const title = payload.title ?? "life-base";
  const options = {
    body: payload.body ?? "Yeni bir hatirlatman var.",
    icon: "/icons/icon-192.svg",
    badge: "/icons/icon-192.svg",
    data: payload.url ?? "/"
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  const targetUrl = event.notification.data ?? "/";
  event.notification.close();
  event.waitUntil(clients.openWindow(targetUrl));
});
