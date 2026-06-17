import {
  createPushSubscription,
  fetchPushConfig
} from "./api/notifications";
import { registerServiceWorker, subscribeToPush } from "./pwa";

function serializeSubscription(subscription) {
  const payload = subscription.toJSON();
  return {
    endpoint: subscription.endpoint,
    keys: {
      p256dh: payload.keys?.p256dh ?? "",
      auth: payload.keys?.auth ?? ""
    }
  };
}

export async function enablePushNotifications({ promptForPermission = false } = {}) {
  if (!("Notification" in window) || !("serviceWorker" in navigator)) {
    return {
      supported: false,
      status: "unsupported",
      message: "Bu tarayicida web push desteklenmiyor."
    };
  }

  const config = await fetchPushConfig();
  if (!config.enabled) {
    return {
      supported: true,
      config,
      status: "disabled",
      message: "Push omurgasi hazir, ama VAPID ayari henuz tam degil."
    };
  }

  let permission = Notification.permission;
  if (permission === "default" && promptForPermission) {
    permission = await Notification.requestPermission();
  }

  if (permission !== "granted") {
    return {
      supported: true,
      config,
      status: "idle",
      message: "Bildirimler varsayilan olarak acik. Izin verdiginde bu cihaza gelir."
    };
  }

  const registration = await registerServiceWorker();
  const subscription = await subscribeToPush(registration, config.vapid_public_key);
  if (!subscription) {
    return {
      supported: true,
      config,
      status: "error",
      message: "Push subscription olusturulamadi."
    };
  }

  await createPushSubscription({
    ...serializeSubscription(subscription),
    device_label: "iPhone Web App",
    user_agent: navigator.userAgent
  });

  return {
    supported: true,
    config,
    status: "ready",
    message: "Bildirimler acik. Reminder geldiginde bu cihaza dusecek."
  };
}
