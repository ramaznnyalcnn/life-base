import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import NotificationControl from "./NotificationControl";

vi.mock("../api/notifications", () => ({
  deletePushSubscription: vi.fn(),
  sendTestNotification: vi.fn()
}));

vi.mock("../notifications", () => ({
  enablePushNotifications: vi.fn()
}));

import {
  deletePushSubscription,
  sendTestNotification
} from "../api/notifications";
import { enablePushNotifications } from "../notifications";

describe("NotificationControl", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.defineProperty(window, "Notification", {
      configurable: true,
      value: {
        permission: "default",
        requestPermission: vi.fn().mockResolvedValue("granted")
      }
    });
    Object.defineProperty(window, "navigator", {
      configurable: true,
      value: {
        ...window.navigator,
        userAgent: "Mozilla/5.0",
        serviceWorker: {
          register: vi.fn(),
          getRegistration: vi.fn().mockResolvedValue({
            pushManager: {
              getSubscription: vi.fn().mockResolvedValue({
                endpoint: "https://push.example.test/subscriptions/123",
                unsubscribe: vi.fn().mockResolvedValue(true)
              })
            }
          })
        }
      }
    });
  });

  it("shows disabled state when backend push is not configured", async () => {
    enablePushNotifications.mockResolvedValue({
      supported: true,
      config: {
        enabled: false,
        vapid_public_key: ""
      },
      status: "disabled",
      message: "Push omurgasi hazir, ama VAPID ayari henuz tam degil."
    });

    render(<NotificationControl />);

    expect(await screen.findByText(/VAPID ayari henuz tam degil/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Bildirimleri Ac" })).toBeDisabled();
  });

  it("subscribes and stores push subscription when enabled", async () => {
    enablePushNotifications
      .mockResolvedValueOnce({
        supported: true,
        config: {
          enabled: true,
          vapid_public_key: "BOrnekPublicKey1234567890"
        },
        status: "idle",
        message: "Bildirimler varsayilan olarak acik. Izin verdiginde bu cihaza gelir."
      })
      .mockResolvedValueOnce({
        supported: true,
        config: {
          enabled: true,
          vapid_public_key: "BOrnekPublicKey1234567890"
        },
        status: "ready",
        message: "Bildirimler acildi. Reminder geldiginde bu cihaza dusecek."
      });

    const user = userEvent.setup();
    render(<NotificationControl />);

    await user.click(await screen.findByRole("button", { name: "Bildirimleri Ac" }));

    expect(enablePushNotifications).toHaveBeenLastCalledWith({ promptForPermission: true });
    expect(await screen.findByText(/Bildirimler acildi/i)).toBeInTheDocument();
  });

  it("removes subscription when disabled", async () => {
    enablePushNotifications.mockResolvedValue({
      supported: true,
      config: {
        enabled: true,
        vapid_public_key: "BOrnekPublicKey1234567890"
      },
      status: "ready",
      message: "Bildirimler acik. Reminder geldiginde bu cihaza dusecek."
    });
    Object.defineProperty(window, "Notification", {
      configurable: true,
      value: {
        permission: "granted",
        requestPermission: vi.fn().mockResolvedValue("granted")
      }
    });

    const user = userEvent.setup();
    render(<NotificationControl />);

    await user.click(await screen.findByRole("button", { name: "Kapat" }));

    expect(deletePushSubscription).toHaveBeenCalledWith("https://push.example.test/subscriptions/123");
  });

  it("sends test notification after subscription is ready", async () => {
    enablePushNotifications.mockResolvedValue({
      supported: true,
      config: {
        enabled: true,
        vapid_public_key: "BOrnekPublicKey1234567890"
      },
      status: "ready",
      message: "Bildirimler acik. Reminder geldiginde bu cihaza dusecek."
    });
    Object.defineProperty(window, "Notification", {
      configurable: true,
      value: {
        permission: "granted",
        requestPermission: vi.fn().mockResolvedValue("granted")
      }
    });
    sendTestNotification.mockResolvedValue({
      sent_count: 1,
      failed_count: 0,
      deactivated_count: 0,
      reminder_count: 0
    });

    const user = userEvent.setup();
    render(<NotificationControl />);

    await user.click(await screen.findByRole("button", { name: "Test Gonder" }));

    expect(sendTestNotification).toHaveBeenCalledWith({
      title: "Life OS Test",
      body: "Bildirim hatti calisiyor.",
      url: "/"
    });
    expect(await screen.findByText(/Test bildirimi gonderildi/i)).toBeInTheDocument();
  });
});
