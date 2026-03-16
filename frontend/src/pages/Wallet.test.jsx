import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import WalletPage from "./Wallet";

vi.mock("../api/wallet", () => ({
  fetchWalletSummary: vi.fn(),
  fetchCardStatements: vi.fn()
}));

vi.mock("../api/accounts", () => ({
  createAccount: vi.fn(),
  updateAccount: vi.fn()
}));

import { fetchCardStatements, fetchWalletSummary } from "../api/wallet";
import { updateAccount } from "../api/accounts";

describe("WalletPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders wallet metrics and account cards", async () => {
    const user = userEvent.setup();

    fetchWalletSummary.mockResolvedValue({
      liquid_balance: "30500.00",
      total_card_available: "16000.00",
      total_card_used: "24000.00",
      total_credit_limit: "40000.00",
      net_worth: "6500.00",
      previous_month_net: "1300.00",
      previous_year_net: "5000.00",
      active_account_count: 3,
      active_card_count: 1,
      weekly_flow: {
        total_income: "5000.00",
        total_expense: "2000.00",
        net_flow: "3000.00"
      },
      monthly_flow: {
        total_income: "5000.00",
        total_expense: "2000.00",
        net_flow: "3000.00"
      },
      accounts: [
        {
          id: 1,
          name: "Akbank Platinum",
          type: "credit_card",
          balance: "16000.00",
          credit_limit: "40000.00",
          used_credit: "24000.00",
          utilization_ratio: "0.6000",
          statement_day: 25,
          due_day: 5
        },
        {
          id: 2,
          name: "Enpara",
          type: "bank",
          balance: "24000.00",
          currency: "TRY"
        }
      ]
    });
    fetchCardStatements.mockResolvedValue([
      {
        account_id: 1,
        account_name: "Akbank Platinum",
        period_start: "2026-02-21",
        period_end: "2026-03-20",
        due_date: "2026-04-05",
        auto_resets_at: "2026-03-21T00:00:00+00:00",
        statement_amount: "2500.00",
        payment_activity: "500.00",
        transaction_count: 3
      }
    ]);

    render(<WalletPage />);

    expect(await screen.findByText("Ana Toplam")).toBeInTheDocument();
    expect(screen.getByText("Gelir Gider")).toBeInTheDocument();
    expect(screen.getByText("Kartlar")).toBeInTheDocument();
    expect(screen.getByText("Diger Hesaplar")).toBeInTheDocument();
    expect(screen.getAllByText("Akbank Platinum").length).toBeGreaterThanOrEqual(1);
    expect(screen.queryByText("Secili Kart")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Kartlar/i }));

    expect(screen.getAllByText("Akbank Platinum").length).toBeGreaterThanOrEqual(2);
    expect(screen.getAllByText("Secili Kart").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText("Kart Bilgileri")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Kart Ekle" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Ayar" })).toBeInTheDocument();
    expect(screen.getByText("OD")).toBeInTheDocument();
    expect(screen.getByText("RS")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Diger Hesaplar/i }));

    expect(screen.getAllByText("Enpara").length).toBeGreaterThanOrEqual(2);
    expect(screen.getByText("BK")).toBeInTheDocument();
    expect(screen.getAllByText("Banka")[1]).toBeInTheDocument();
  });

  it("opens card settings from card and updates fields", async () => {
    fetchWalletSummary.mockResolvedValue({
      liquid_balance: "1000.00",
      total_card_available: "16000.00",
      total_card_used: "24000.00",
      total_credit_limit: "40000.00",
      net_worth: "6500.00",
      previous_month_net: "1300.00",
      previous_year_net: "5000.00",
      active_account_count: 1,
      active_card_count: 1,
      weekly_flow: {
        total_income: "5000.00",
        total_expense: "2000.00",
        net_flow: "3000.00"
      },
      monthly_flow: {
        total_income: "5000.00",
        total_expense: "2000.00",
        net_flow: "3000.00"
      },
      accounts: [
        {
          id: 1,
          name: "Akbank Platinum",
          type: "credit_card",
          balance: "16000.00",
          credit_limit: "40000.00",
          used_credit: "24000.00",
          utilization_ratio: "0.6000",
          statement_day: 25,
          due_day: 5,
          issuer: "Akbank",
          is_active: true
        }
      ]
    });
    fetchCardStatements.mockResolvedValue([]);
    updateAccount.mockResolvedValue({});

    const user = userEvent.setup();
    render(<WalletPage />);

    await user.click(await screen.findByRole("button", { name: /Kartlar/i }));
    await user.click(await screen.findByRole("button", { name: "Ayar" }));
    await user.clear(screen.getByLabelText("Kart Adi"));
    await user.type(screen.getByLabelText("Kart Adi"), "Akbank Platinum Plus");
    await user.click(screen.getByRole("button", { name: "Guncelle" }));

    expect(updateAccount).toHaveBeenCalledWith(
      1,
      expect.objectContaining({
        name: "Akbank Platinum Plus",
        type: "credit_card"
      })
    );
  });

  it("keeps card payments out of expense totals", async () => {
    fetchWalletSummary.mockResolvedValue({
      liquid_balance: "1000.00",
      total_card_available: "16000.00",
      total_card_used: "24000.00",
      total_credit_limit: "40000.00",
      net_worth: "6500.00",
      previous_month_net: "1300.00",
      previous_year_net: "5000.00",
      active_account_count: 2,
      active_card_count: 1,
      weekly_flow: {
        total_income: "5000.00",
        total_expense: "800.00",
        total_payments: "490.00",
        net_flow: "4200.00"
      },
      monthly_flow: {
        total_income: "5000.00",
        total_expense: "800.00",
        total_payments: "490.00",
        net_flow: "4200.00"
      },
      accounts: [
        {
          id: 1,
          name: "Ziraat",
          type: "credit_card",
          balance: "16000.00",
          credit_limit: "40000.00",
          used_credit: "24000.00",
          utilization_ratio: "0.6000",
          statement_day: 25,
          due_day: 12,
          issuer: "Ziraat"
        },
        {
          id: 2,
          name: "Enpara",
          type: "bank",
          balance: "24000.00",
          currency: "TRY"
        }
      ]
    });
    fetchCardStatements.mockResolvedValue([]);

    render(<WalletPage />);

    expect(await screen.findByText("Kart Odemeleri")).toBeInTheDocument();
    expect(screen.getByText("Kredi kartina yapilan odemeler giderden ayri izlenir.")).toBeInTheDocument();
    expect(screen.getByText(/Kart odemeleri ₺490,00 ama bunlar gider hesabina dahil edilmiyor./i)).toBeInTheDocument();
  });
});
