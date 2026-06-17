import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import HistoryPage from "./HistoryPage";

vi.mock("../api/accounts", () => ({
  fetchAccounts: vi.fn()
}));

vi.mock("../api/transactions", () => ({
  fetchTransactions: vi.fn(),
  updateTransaction: vi.fn(),
  deleteTransaction: vi.fn()
}));

import { fetchAccounts } from "../api/accounts";
import {
  deleteTransaction,
  fetchTransactions,
  updateTransaction
} from "../api/transactions";

async function scrollToHistoryScene() {
  await screen.findByText("Toplam Net Durum");
  const scrollShell = document.querySelector(".analysis-scroll-shell");
  expect(scrollShell).not.toBeNull();
  fireEvent.wheel(scrollShell, { deltaY: 1200 });
  await screen.findByPlaceholderText("Kira, kahve, maas...");
}

describe("HistoryPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    fetchAccounts.mockResolvedValue([
      {
        id: 1,
        name: "Enpara",
        type: "bank"
      },
      {
        id: 2,
        name: "Akbank Platinum",
        type: "credit_card"
      }
    ]);
  });

  it("renders transaction list", async () => {
    const user = userEvent.setup();
    fetchTransactions.mockResolvedValue([
      {
        id: 10,
        account_id: 1,
        category_name: "Market",
        type: "expense",
        amount: "350.00",
        description: "Migros",
        note: "Haftalik alim",
        statement_month: "2026-03-01",
        occurred_at: "2026-03-09T10:00:00+00:00"
      }
    ]);

    render(<HistoryPage />);

    expect(await screen.findByText("Toplam Net Durum")).toBeInTheDocument();
    expect(screen.getByText("Zeka Onerileri")).toBeInTheDocument();

    await scrollToHistoryScene();

    expect(screen.getByPlaceholderText("Kira, kahve, maas...")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Filtre" })).toBeInTheDocument();
    expect(screen.getByText("Migros")).toBeInTheDocument();
    expect(screen.getAllByText("Harcama")[0]).toBeInTheDocument();
    expect(screen.getAllByText(/Enpara/i)[0]).toBeInTheDocument();
    expect(screen.getByLabelText("Kategori Market")).toBeInTheDocument();
    expect(screen.getByText("MK")).toBeInTheDocument();
    expect(screen.getByText(/Not Haftalik alim/i)).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Detay" }));

    expect(screen.getByText("Ekstre Ayi")).toBeInTheDocument();
    expect(screen.getAllByText(/Mart 2026/i)[0]).toBeInTheDocument();
    expect(screen.getAllByText("Hesap")[0]).toBeInTheDocument();
    expect(screen.getAllByText(/Enpara/i)[0]).toBeInTheDocument();
  });

  it("applies filters", async () => {
    fetchTransactions
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([
        {
          id: 11,
          account_id: 2,
          category_name: null,
          type: "payment",
          amount: "5000.00",
          description: "Kart odemesi",
          note: null,
          statement_month: "2026-03-01",
          occurred_at: "2026-03-09T12:00:00+00:00"
        }
      ]);

    const user = userEvent.setup();
    render(<HistoryPage />);

    await scrollToHistoryScene();
    await user.click(screen.getByRole("button", { name: "Filtre" }));
    const drawerSelects = await screen.findAllByRole("combobox");
    await user.selectOptions(drawerSelects[1], "payment");
    await user.type(screen.getByPlaceholderText("Kira, kahve, maas..."), "kart");
    await user.click(screen.getByRole("button", { name: "Filtreyi Uygula" }));

    expect(fetchTransactions).toHaveBeenLastCalledWith({
      accountId: "",
      type: "payment",
      search: "kart"
    });
    expect(await screen.findByText("Kart odemesi")).toBeInTheDocument();
  });

  it("filters analysis view by category and custom date range", async () => {
    fetchTransactions.mockResolvedValue([
      {
        id: 21,
        account_id: 1,
        category_name: "Market",
        type: "expense",
        amount: "350.00",
        description: "Migros",
        note: null,
        statement_month: "2026-03-01",
        occurred_at: "2026-03-09T10:00:00+00:00"
      },
      {
        id: 22,
        account_id: 1,
        category_name: "Ulasim",
        type: "expense",
        amount: "90.00",
        description: "Taksi",
        note: null,
        statement_month: "2026-02-01",
        occurred_at: "2026-02-01T10:00:00+00:00"
      }
    ]);

    const user = userEvent.setup();
    render(<HistoryPage />);

    await scrollToHistoryScene();
    await user.click(screen.getByRole("button", { name: "Detayli Analiz & Grafikleri Goster" }));
    await waitFor(() => expect(screen.getByRole("option", { name: "Market" })).toBeInTheDocument());
    await user.selectOptions(screen.getByLabelText("Kategori"), "Market");

    await user.clear(screen.getByLabelText("Baslangic"));
    await user.type(screen.getByLabelText("Baslangic"), "2026-04-01");

    expect(await screen.findByText("Bu filtrelerle islem bulunamadi")).toBeInTheDocument();
  });

  it("does not count card payments as expense in analysis totals", async () => {
    const now = new Date();
    const thisMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
    fetchTransactions.mockResolvedValue([
      {
        id: 31,
        account_id: 1,
        category_name: "Market",
        type: "expense",
        amount: "350.00",
        description: "Migros",
        note: null,
        statement_month: `${thisMonth}-01`,
        occurred_at: `${thisMonth}-09T10:00:00+00:00`
      },
      {
        id: 32,
        account_id: 1,
        category_name: null,
        type: "payment",
        amount: "490.00",
        description: "Ziraat kart odemesi",
        note: null,
        statement_month: `${thisMonth}-01`,
        occurred_at: `${thisMonth}-10T12:00:00+00:00`
      }
    ]);

    render(<HistoryPage />);

    const matches = await screen.findAllByText((content, element) =>
      element?.tagName !== "SCRIPT" && (element?.textContent ?? "").includes("Kart odemeleri yansitilmiyor") && (element?.textContent ?? "").includes("490")
    );
    expect(matches.length).toBeGreaterThan(0);
  });

  it("updates and deletes transactions", async () => {
    fetchTransactions
      .mockResolvedValueOnce([
        {
          id: 12,
          account_id: 1,
          category_name: "Kahve",
          type: "expense",
          amount: "120.00",
          description: "Kahve",
          note: null,
          statement_month: null,
          occurred_at: "2026-03-09T08:30:00+00:00"
        }
      ])
      .mockResolvedValue([
        {
          id: 12,
          account_id: 1,
          category_name: "Kafe",
          type: "expense",
          amount: "120.00",
          description: "Kahve",
          note: "Ofis ici",
          statement_month: null,
          occurred_at: "2026-03-09T08:30:00+00:00"
        }
      ]);
    updateTransaction.mockResolvedValue({});
    deleteTransaction.mockResolvedValue(null);

    const user = userEvent.setup();
    render(<HistoryPage />);

    await scrollToHistoryScene();
    await user.click(await screen.findByRole("button", { name: "Duzenle" }));
    await user.clear(screen.getByLabelText("Tutar"));
    await user.type(screen.getByLabelText("Tutar"), "200");
    await user.selectOptions(screen.getByLabelText("Kategori", { selector: "#transaction-category-12" }), "Kahve");
    await user.clear(screen.getByLabelText("Aciklama"));
    await user.type(screen.getByLabelText("Aciklama"), "Kahve guncel");
    await user.type(screen.getByLabelText("Not"), "Ofis ici");
    await user.click(screen.getByRole("button", { name: "Kaydet" }));

    expect(updateTransaction).toHaveBeenCalledWith(
      12,
      expect.objectContaining({
        account_id: 1,
        category_name: "Kahve",
        type: "expense",
        amount: "200",
        description: "Kahve guncel",
        note: "Ofis ici"
      })
    );

    await user.click(await screen.findByRole("button", { name: "Sil" }));
    expect(deleteTransaction).toHaveBeenCalledWith(12);
  });
});
