import { render, screen } from "@testing-library/react";
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

    expect(await screen.findByText("Finans Analizi")).toBeInTheDocument();
    expect(screen.getByText("Gelir ve gider trendi")).toBeInTheDocument();
    expect(screen.getByText("Daire grafik ile cikislar")).toBeInTheDocument();
    expect(screen.getByText("Harcama Davranisi")).toBeInTheDocument();
    expect(screen.getByText("Analiz")).toBeInTheDocument();
    expect(screen.getAllByText(/Mart 2026/i)[0]).toBeInTheDocument();
    expect(screen.getByText(/2026 Ozeti/i)).toBeInTheDocument();
    expect(screen.getByText("Aylik Arsiv")).toBeInTheDocument();
    expect(screen.getByText("Oneriler")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Arama" })).toBeInTheDocument();
    expect(screen.getByText("Migros")).toBeInTheDocument();
    expect(screen.getAllByText("Harcama")[0]).toBeInTheDocument();
    expect(screen.getAllByText(/Enpara/i)[0]).toBeInTheDocument();
    expect(screen.getByLabelText("Kategori Market")).toBeInTheDocument();
    expect(screen.getByText("MK")).toBeInTheDocument();
    expect(screen.getByText(/Not Haftalik alim/i)).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Yillar" }));
    expect(screen.getByText("Yillik Arsiv")).toBeInTheDocument();
    expect(screen.getByText("Tum yillarin ozetleri ve eski analizler")).toBeInTheDocument();

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

    await user.click(await screen.findByRole("button", { name: "Arama" }));
    await user.selectOptions(await screen.findByLabelText("Tur"), "payment");
    await user.type(screen.getByLabelText("Ara"), "kart");
    await user.click(screen.getByRole("button", { name: "Uygula" }));

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

    expect(await screen.findByText("Migros")).toBeInTheDocument();
    expect(screen.getByText("Taksi")).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText("Kategori"), "Market");
    expect(screen.getByText("Migros")).toBeInTheDocument();
    expect(screen.queryByText("Taksi")).not.toBeInTheDocument();

    await user.clear(screen.getByLabelText("Baslangic"));
    await user.type(screen.getByLabelText("Baslangic"), "2026-04-01");
    expect(await screen.findByText("Bu filtrelerle islem bulunamadi")).toBeInTheDocument();
  });

  it("does not count card payments as expense in analysis totals", async () => {
    fetchTransactions.mockResolvedValue([
      {
        id: 31,
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
        id: 32,
        account_id: 1,
        category_name: null,
        type: "payment",
        amount: "490.00",
        description: "Ziraat kart odemesi",
        note: null,
        statement_month: "2026-03-01",
        occurred_at: "2026-03-10T12:00:00+00:00"
      }
    ]);

    render(<HistoryPage />);

    expect(await screen.findByText("Kart odemeleri ayri izleniyor: ₺490,00")).toBeInTheDocument();
    expect(screen.getByText("Gider toplamindan ayri tutulur")).toBeInTheDocument();
    expect(screen.getAllByText(/Gider ₺350,00/i).length).toBeGreaterThanOrEqual(1);
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

    await user.click(await screen.findByRole("button", { name: "Duzenle" }));
    await user.clear(screen.getByLabelText("Tutar"));
    await user.type(screen.getByLabelText("Tutar"), "200");
    await user.clear(screen.getByLabelText("Kategori", { selector: "#transaction-category-12" }));
    await user.type(screen.getByLabelText("Kategori", { selector: "#transaction-category-12" }), "Kafe");
    await user.clear(screen.getByLabelText("Aciklama"));
    await user.type(screen.getByLabelText("Aciklama"), "Kahve guncel");
    await user.type(screen.getByLabelText("Not"), "Ofis ici");
    await user.click(screen.getByRole("button", { name: "Kaydet" }));

    expect(updateTransaction).toHaveBeenCalledWith(
      12,
      expect.objectContaining({
        account_id: 1,
        category_name: "Kafe",
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
