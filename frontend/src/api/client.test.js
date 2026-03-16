vi.mock("../device", () => ({
  getOrCreateDeviceId: () => "device-test",
}));

import { apiRequest, API_BASE_URL } from "./client";

describe("api client", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
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
});
