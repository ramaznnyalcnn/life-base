import { registerServiceWorker, subscribeToPush } from "./pwa";

describe("pwa helpers", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("registers the service worker on localhost too", async () => {
    const registration = { scope: "/" };

    Object.defineProperty(window, "navigator", {
      configurable: true,
      value: {
        ...window.navigator,
        serviceWorker: {
          register: vi.fn().mockResolvedValue(registration)
        }
      }
    });

    await expect(registerServiceWorker()).resolves.toBe(registration);
    expect(window.navigator.serviceWorker.register).toHaveBeenCalledWith("/sw.js");
  });

  it("returns the existing push subscription when present", async () => {
    const existingSubscription = { endpoint: "https://push.example.test/subscriptions/123" };
    const registration = {
      pushManager: {
        getSubscription: vi.fn().mockResolvedValue(existingSubscription),
        subscribe: vi.fn()
      }
    };

    await expect(
      subscribeToPush(registration, "BOrnekPublicKey1234567890"),
    ).resolves.toBe(existingSubscription);
    expect(registration.pushManager.subscribe).not.toHaveBeenCalled();
  });
});
