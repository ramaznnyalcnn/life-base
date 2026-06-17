import { act, fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import App from "./App";
import { fetchBackendHealth } from "./api/auth";
import { getStoredSession } from "./auth/session";

vi.mock("./api/auth", () => ({
  fetchBackendHealth: vi.fn().mockResolvedValue({
    mode: {
      single_user: true
    }
  }),
  fetchCurrentUser: vi.fn()
}));

vi.mock("./auth/session", () => ({
  SESSION_EVENT_NAME: "lifeos:session-changed",
  clearStoredSession: vi.fn(),
  getStoredSession: vi.fn(() => null),
  setStoredSession: vi.fn()
}));

vi.mock("./notifications", () => ({
  enablePushNotifications: vi.fn().mockResolvedValue(undefined)
}));

vi.mock("./pages/Wallet", () => ({
  default: () => <div>Cuzdan Ekrani</div>
}));

vi.mock("./pages/Calendar", () => ({
  default: () => <div>Takvim Ekrani</div>
}));

vi.mock("./pages/AddPage", () => ({
  default: () => <div>Ekle Ekrani</div>
}));

vi.mock("./pages/HistoryPage", () => ({
  default: () => <div>Gecmis Ekrani</div>
}));

vi.mock("./pages/ManagePage", () => ({
  default: () => <div>Yonetim Ekrani</div>
}));

vi.mock("./pages/SettingsPage", () => ({
  default: () => <div>Ayarlar Ekrani</div>
}));

describe("App", () => {
  beforeEach(() => {
    fetchBackendHealth.mockResolvedValue({
      mode: {
        single_user: true
      }
    });
    getStoredSession.mockReturnValue(null);
  });

  it("shows the management screen from bottom navigation", async () => {
    const user = userEvent.setup();

    render(<App />);

    expect(await screen.findByText("Cuzdan Ekrani")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Yonet" }));

    expect(screen.getByText("Yonetim Ekrani")).toBeInTheDocument();
  });

  it("switches pages while sliding across the dock after a long press", async () => {
    vi.useFakeTimers();
    const originalElementFromPoint = document.elementFromPoint;
    const elementFromPointMock = vi.fn();
    Object.defineProperty(document, "elementFromPoint", {
      configurable: true,
      value: elementFromPointMock
    });

    try {
      render(<App />);
      await act(async () => {
        await Promise.resolve();
      });

      const navigation = screen.getByRole("navigation", { name: "Ana gezinme" });
      const walletButton = screen.getByRole("button", { name: "Cuzdan" });
      const addButton = screen.getByRole("button", { name: "Ekle" });

      fireEvent.pointerDown(walletButton, {
        button: 0,
        pointerId: 7,
        clientX: 4,
        clientY: 4
      });

      act(() => {
        vi.advanceTimersByTime(450);
      });
      elementFromPointMock.mockReturnValue(addButton);

      act(() => {
        fireEvent.pointerMove(navigation, {
          pointerId: 7,
          clientX: 12,
          clientY: 12
        });
      });

      act(() => {
        fireEvent.pointerUp(navigation, { pointerId: 7 });
        vi.runAllTimers();
      });

      expect(screen.getByText("Ekle Ekrani")).toBeInTheDocument();
    } finally {
      Object.defineProperty(document, "elementFromPoint", {
        configurable: true,
        value: originalElementFromPoint
      });
      vi.useRealTimers();
    }
  });

  it("shows the login screen when secure mode is enabled and there is no session", async () => {
    fetchBackendHealth.mockResolvedValueOnce({
      mode: {
        single_user: false
      }
    });

    render(<App />);

    expect(await screen.findByRole("heading", { name: "Giris yap" })).toBeInTheDocument();
  });
});
