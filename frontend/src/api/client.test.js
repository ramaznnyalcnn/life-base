vi.mock("../device", () => ({
  getOrCreateDeviceId: () => "device-test",
}));

vi.mock("../auth/session", () => ({
  clearStoredSession: vi.fn(),
  getStoredAccessToken: vi.fn(() => "")
}));

import { apiRequest, API_BASE_URL } from "./client";
import { clearStoredSession, getStoredAccessToken } from "../auth/session";

describe("api client", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
    getStoredAccessToken.mockReturnValue("");
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("adds the device id header to requests", async () => {
    fetch.mockResolvedValue({
      ok: true,
      json: async () => ({ ok: true }),
    });

    await apiRequest("/events/dashboard?include_past=true");

    expect(fetch).toHaveBeenCalledWith(
      `${API_BASE_URL}/events/dashboard?include_past=true`,
      expect.objectContaining({
        headers: expect.objectContaining({
          "X-Device-Id": "device-test",
        }),
      }),
    );
  });

  it("adds the access token header when a session exists", async () => {
    getStoredAccessToken.mockReturnValue("token-123");
    fetch.mockResolvedValue({
      ok: true,
      json: async () => ({ ok: true }),
    });

    await apiRequest("/wallet/summary");

    expect(fetch).toHaveBeenCalledWith(
      `${API_BASE_URL}/wallet/summary`,
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer token-123",
        }),
      }),
    );
  });

  it("returns a clear message when fetch fails before a response arrives", async () => {
    fetch.mockRejectedValue(new TypeError("Failed to fetch"));

    await expect(apiRequest("/events")).rejects.toThrow(
      "API'ye ulasilamadi. Backend calisiyorsa veritabani migrationlarini guncelleyin.",
    );
  });

  it("surfaces backend migration details from json error payloads", async () => {
    fetch.mockResolvedValue({
      ok: false,
      status: 503,
      json: async () => ({
        detail:
          "Veritabani semasi guncel degil. backend dizininde '../.venv/bin/alembic -c alembic.ini upgrade head' calistirin.",
      }),
    });

    await expect(apiRequest("/events")).rejects.toThrow("Veritabani semasi guncel degil.");
  });

  it("clears the stored session on unauthorized responses", async () => {
    getStoredAccessToken.mockReturnValue("expired-token");
    fetch.mockResolvedValue({
      ok: false,
      status: 401,
      json: async () => ({
        detail: "Kimlik dogrulamasi gerekiyor.",
      }),
    });

    await expect(apiRequest("/events")).rejects.toThrow("Kimlik dogrulamasi gerekiyor.");
    expect(clearStoredSession).toHaveBeenCalled();
  });
});
