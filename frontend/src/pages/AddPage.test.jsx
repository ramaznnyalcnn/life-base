import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import AddPage from "./AddPage";

vi.mock("../api/accounts", () => ({
  fetchAccounts: vi.fn().mockResolvedValue([
    { id: 1, name: "Enpara", type: "bank" },
    { id: 2, name: "Bonus", type: "credit_card" }
  ])
}));

vi.mock("../api/transactions", () => ({
  createTransaction: vi.fn()
}));

vi.mock("../api/events", () => ({
  createEvent: vi.fn(),
  createRecurringEvent: vi.fn()
}));

vi.mock("../api/medications", () => ({
  createMedication: vi.fn()
}));

import { createTransaction } from "../api/transactions";
import { createEvent, createRecurringEvent } from "../api/events";
import { createMedication } from "../api/medications";

describe("AddPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders medication entry tab", async () => {
    render(<AddPage />);
    expect(await screen.findByRole("button", { name: /İşlem/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Etkinlik/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Rutin/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /İlaç/ })).toBeInTheDocument();
  });

  it("transaction tab submits with correct payload", async () => {
    createTransaction.mockResolvedValue({ id: 1 });
    const user = userEvent.setup();
    render(<AddPage />);

    await screen.findByLabelText("Tutar (₺)");

    await user.type(screen.getByLabelText("Tutar (₺)"), "150");
    await user.selectOptions(screen.getByLabelText("Hesap"), "1");
    await user.selectOptions(screen.getByLabelText("Kategori"), "Market");
    await user.type(screen.getByLabelText("Açıklama"), "Test harcama");

    await user.click(screen.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      expect(createTransaction).toHaveBeenCalledWith(
        expect.objectContaining({
          account_id: 1,
          type: "expense",
          amount: "150",
          category_name: "Market",
          description: "Test harcama"
        })
      );
    });
  });

  it("switches to etkinlik tab and submits event", async () => {
    createEvent.mockResolvedValue({ id: 5 });
    const user = userEvent.setup();
    render(<AddPage />);

    await user.click(await screen.findByRole("button", { name: /Etkinlik/ }));
    await user.type(screen.getByLabelText("Başlık"), "Doktor randevusu");
    await user.click(screen.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      expect(createEvent).toHaveBeenCalledWith(
        expect.objectContaining({ title: "Doktor randevusu" })
      );
    });
  });

  it("switches to rutin tab and submits recurring event", async () => {
    createRecurringEvent.mockResolvedValue({ id: 3 });
    const user = userEvent.setup();
    render(<AddPage />);

    await user.click(await screen.findByRole("button", { name: /Rutin/ }));
    await user.type(screen.getByLabelText("Başlık"), "Spor");
    await user.click(screen.getByRole("button", { name: "Pzt" }));
    await user.click(screen.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      expect(createRecurringEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          title: "Spor",
          weekdays: [0]
        })
      );
    });
  });

  it("shows success banner after transaction save", async () => {
    createTransaction.mockResolvedValue({ id: 1 });
    const user = userEvent.setup();
    render(<AddPage />);

    await screen.findByLabelText("Tutar (₺)");

    await user.type(screen.getByLabelText("Tutar (₺)"), "50");
    await user.selectOptions(screen.getByLabelText("Hesap"), "1");
    await user.type(screen.getByLabelText("Açıklama"), "Kahve");

    await user.click(screen.getByRole("button", { name: "Kaydet" }));

    expect(await screen.findByText("İşlem kaydedildi.")).toBeInTheDocument();
  });

  it("creates an interval medication schedule", async () => {
    createMedication.mockResolvedValue({ id: 8 });
    const user = userEvent.setup();
    render(<AddPage />);
    await user.click(await screen.findByRole("button", { name: /İlaç/ }));
    await user.type(screen.getByLabelText("İlaç adı"), "Vitamin D");
    await user.type(screen.getByLabelText("Doz"), "1 tablet");
    await user.selectOptions(screen.getByLabelText("Program tipi"), "interval");
    await user.clear(screen.getByLabelText("Kaç günde bir?"));
    await user.type(screen.getByLabelText("Kaç günde bir?"), "2");
    await user.click(screen.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => expect(createMedication).toHaveBeenCalledWith(
      expect.objectContaining({ schedule_mode: "interval", weekdays: [], interval_days: 2 })
    ));
  });
});
