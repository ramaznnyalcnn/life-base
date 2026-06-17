import { clarifyAI, executeAI } from "./ai";
import { API_BASE_URL } from "./client";

describe("ai api client", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("calls execute endpoint", async () => {
    fetch.mockResolvedValue({
      ok: true,
      json: async () => ({ status: "completed" })
    });

    const result = await executeAI("350 tl migros");

    expect(fetch).toHaveBeenCalledWith(
      `${API_BASE_URL}/ai/execute`,
      expect.objectContaining({
        method: "POST"
      })
    );
    expect(result.status).toBe("completed");
  });

  it("calls clarify endpoint", async () => {
    fetch.mockResolvedValue({
      ok: true,
      json: async () => ({ status: "completed" })
    });

    await clarifyAI("120 kahve", "enpara");

    expect(fetch).toHaveBeenCalledWith(
      `${API_BASE_URL}/ai/clarify`,
      expect.objectContaining({
        method: "POST"
      })
    );
  });
});
