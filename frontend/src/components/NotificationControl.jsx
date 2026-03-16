import { useEffect, useState } from "react";

import {
  deletePushSubscription,
  sendTestNotification
} from "../api/notifications";
import { enablePushNotifications } from "../notifications";

export default function NotificationControl() {
  const [config, setConfig] = useState({ enabled: false, vapid_public_key: "" });
  const [supported, setSupported] = useState(true);
  const [status, setStatus] = useState("hazirlaniyor");
  const [message, setMessage] = useState("Bildirim durumu kontrol ediliyor.");

  useEffect(() => {
    let cancelled = false;

    async function bootstrap() {
      if (!("Notification" in window) || !("serviceWorker" in navigator)) {
        if (!cancelled) {
          setSupported(false);
          setStatus("unsupported");
          setMessage("Bu tarayicida web push desteklenmiyor.");
        }
        return;
      }

      try {
        const result = await enablePushNotifications();
        if (cancelled) {
          return;
        }

        setSupported(result.supported);
        setConfig(result.config ?? { enabled: false, vapid_public_key: "" });
        setStatus(result.status);
        setMessage(result.message);
      } catch (error) {
        if (!cancelled) {
          setStatus("error");
          setMessage(error.message);
        }
      }
    }

    bootstrap();

    return () => {
      cancelled = true;
    };
  }, []);

  async function handleEnable() {
    try {
      setStatus("working");
      setMessage("Bildirim izni isteniyor...");
      const result = await enablePushNotifications({ promptForPermission: true });
      setConfig(result.config ?? config);
      setStatus(result.status);
      setMessage(result.message);
    } catch (error) {
      setStatus("error");
      setMessage(error.message);
    }
  }

  async function handleDisable() {
    if (!navigator.serviceWorker) {
      return;
    }

    const registration = await navigator.serviceWorker.getRegistration();
    const subscription = await registration?.pushManager?.getSubscription?.();
    if (subscription) {
      await deletePushSubscription(subscription.endpoint);
      await subscription.unsubscribe();
    }
    setStatus("idle");
    setMessage("Bildirim subscription kaldirildi.");
  }

  async function handleSendTest() {
    try {
      setStatus("working");
      setMessage("Test bildirimi gonderiliyor...");
      const result = await sendTestNotification({
        title: "Life OS Test",
        body: "Bildirim hatti calisiyor.",
        url: "/"
      });
      if (result.sent_count > 0) {
        setStatus("ready");
        setMessage("Test bildirimi gonderildi. Cihazina dusmeli.");
        return;
      }
      setStatus("idle");
      setMessage("Aktif bir subscription bulunamadi.");
    } catch (error) {
      setStatus("error");
      setMessage(error.message);
    }
  }

  const canEnable = supported && config.enabled && status !== "working" && status !== "ready";

  return (
    <section className="notification-card">
      <p className="notification-card__text">{message}</p>
      <div className="notification-card__actions">
        <button
          className="secondary-button"
          type="button"
          disabled={!canEnable}
          onClick={handleEnable}
        >
          {status === "working" ? "Hazirlaniyor..." : "Bildirimleri Ac"}
        </button>
        <button
          className="ghost-button"
          type="button"
          disabled={status !== "ready"}
          onClick={handleDisable}
        >
          Kapat
        </button>
        <button
          className="ghost-button"
          type="button"
          disabled={status !== "ready"}
          onClick={handleSendTest}
        >
          Test Gonder
        </button>
      </div>
    </section>
  );
}
