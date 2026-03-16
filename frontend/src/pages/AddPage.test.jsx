import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import AddPage from "./AddPage";

vi.mock("../api/ai", () => ({
  executeAI: vi.fn(),
  clarifyAI: vi.fn()
}));

import { clarifyAI, executeAI } from "../api/ai";

const TEMPLATE_CASES = [
  {
    title: "Haftalik Rutin",
    prompt: "Haftada 3 gun pazartesi carsamba cuma spor rutini ekle"
  },
  {
    title: "Odeme Hatirlaticisi",
    prompt: "Her ayin 28'inde kredi karti odemesi icin hatirlatici ekle"
  },
  {
    title: "Gelir / Gider",
    prompt: "Bugun 860 tl market gideri ekle, hesabim enpara"
  },
  {
    title: "Randevu",
    prompt: "Yarin saat 14:30 disci randevusu ekle"
  }
];

describe("AddPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("fills composer from template and appends optional context to AI message", async () => {
    executeAI.mockResolvedValue({
      status: "completed",
      assistant_message: "Kaydi hazirladim.",
      follow_up_question: null,
      missing_fields: [],
      transaction_id: null,
      event_id: 12
    });

    const user = userEvent.setup();
    render(<AddPage />);

    await user.click(screen.getByRole("button", { name: /Haftalik Rutin/i }));
    expect(screen.getByLabelText("Mesaj")).toHaveValue(
      "Haftada 3 gun pazartesi carsamba cuma spor rutini ekle"
    );

    await user.click(screen.getByRole("button", { name: "Opsiyonel alanlar" }));
    await user.type(screen.getByLabelText("Kategori"), "spor");
    await user.type(screen.getByLabelText("Hesap / Kart"), "enpara");
    await user.click(screen.getByRole("checkbox", { name: "Onemli olarak isaretle" }));
    await user.click(screen.getByRole("button", { name: "AI ile isle" }));

    expect(executeAI).toHaveBeenCalledWith(
      expect.stringContaining("Haftada 3 gun pazartesi carsamba cuma spor rutini ekle")
    );
    expect(executeAI).toHaveBeenCalledWith(expect.stringContaining("Kategori tercihi: spor"));
    expect(executeAI).toHaveBeenCalledWith(expect.stringContaining("Hesap veya kart tercihi: enpara"));
    expect(executeAI).toHaveBeenCalledWith(expect.stringContaining("Kaydi onemli olarak isaretle."));
  });

  it("runs every template prompt through the composer", async () => {
    executeAI.mockResolvedValue({
      status: "completed",
      assistant_message: "Kaydi hazirladim.",
      follow_up_question: null,
      missing_fields: [],
      transaction_id: null,
      event_id: 12
    });

    const user = userEvent.setup();
    render(<AddPage />);

    for (const templateCase of TEMPLATE_CASES) {
      executeAI.mockClear();

      await user.click(screen.getByRole("button", { name: new RegExp(templateCase.title, "i") }));
      expect(screen.getByLabelText("Mesaj")).toHaveValue(templateCase.prompt);

      await user.click(screen.getByRole("button", { name: "AI ile isle" }));
      expect(executeAI).toHaveBeenCalledWith(templateCase.prompt);
    }
  });

  it("shows follow up question when backend needs more info", async () => {
    executeAI.mockResolvedValue({
      status: "needs_input",
      assistant_message: "Ek bilgi gerekli.",
      follow_up_question: "Bunu hangi hesap veya kart ile kaydedeyim?",
      missing_fields: ["account_name"],
      transaction_id: null,
      event_id: null
    });

    const user = userEvent.setup();
    render(<AddPage />);

    await user.type(
      screen.getByLabelText("Mesaj"),
      "120 kahve"
    );
    await user.click(screen.getByRole("button", { name: "AI ile isle" }));

    expect(await screen.findByText("Bunu hangi hesap veya kart ile kaydedeyim?")).toBeInTheDocument();
  });

  it("sends clarification and clears composer after completion", async () => {
    executeAI.mockResolvedValue({
      status: "needs_input",
      assistant_message: "Ek bilgi gerekli.",
      follow_up_question: "Bunu hangi hesap veya kart ile kaydedeyim?",
      missing_fields: ["account_name"],
      transaction_id: null,
      event_id: null
    });
    clarifyAI.mockResolvedValue({
      status: "completed",
      assistant_message: "Kaydi tamamladim.",
      follow_up_question: null,
      missing_fields: [],
      transaction_id: 42,
      event_id: null
    });

    const user = userEvent.setup();
    render(<AddPage />);

    const messageField = screen.getByLabelText("Mesaj");
    await user.type(messageField, "120 kahve");
    await user.click(screen.getByRole("button", { name: "AI ile isle" }));

    await user.type(screen.getByLabelText("Ek bilgi"), "enpara");
    await user.click(screen.getByRole("button", { name: "Bilgiyi gonder" }));

    expect(await screen.findByText("Kaydi tamamladim.")).toBeInTheDocument();
    expect(messageField).toHaveValue("");
  });
});
