import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import ManagePage from "./ManagePage";

vi.mock("../api/accounts", () => ({
  fetchAccounts: vi.fn(),
  createAccount: vi.fn(),
  updateAccount: vi.fn()
}));

vi.mock("../api/wallet", () => ({
  fetchWalletSummary: vi.fn(),
  fetchCardStatements: vi.fn()
}));

import { createAccount, fetchAccounts, updateAccount } from "../api/accounts";
import { fetchCardStatements, fetchWalletSummary } from "../api/wallet";

describe("ManagePage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    fetchWalletSummary.mockResolvedValue({
      liquid_balance: "12000.00",
      total_card_used: "4000.00",
      net_worth: "8000.00"
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
    fetchAccounts.mockResolvedValue([
      {
        id: 1,
        name: "Akbank Platinum",
        type: "credit_card",
        currency: "TRY",
        balance: "16000.00",
        credit_limit: "40000.00",
        statement_day: 25,
        due_day: 5,
        issuer: "Akbank",
        is_active: true
      }
    ]);
  });

  it("renders money status and account list", async () => {
    render(<ManagePage />);

    expect(await screen.findByText("Likit Para")).toBeInTheDocument();
    expect(screen.getByText("Kart Odemeleri")).toBeInTheDocument();
    expect(screen.getByText("Yaklasan Odeme")).toBeInTheDocument();
    expect(screen.getAllByText("Kart Bilgileri").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByRole("button", { name: "Ayar" })).toBeInTheDocument();
    expect(screen.getByText("Hesaplar ve Kartlar")).toBeInTheDocument();
    expect(screen.getAllByText("Akbank Platinum").length).toBeGreaterThanOrEqual(1);
  });

  it("creates a new account", async () => {
    createAccount.mockResolvedValue({ id: 2 });

    const user = userEvent.setup();
    render(<ManagePage />);

    await user.type(await screen.findByLabelText("Ad"), "Enpara");
    await user.type(screen.getByLabelText("Bakiye"), "2500");
    await user.click(screen.getByRole("button", { name: "Hesap Ekle" }));

    expect(createAccount).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Enpara",
        type: "bank",
        balance: "2500"
      })
    );
  });

  it("updates active state", async () => {
    updateAccount.mockResolvedValue({ id: 1 });

    const user = userEvent.setup();
    render(<ManagePage />);

    await user.click(await screen.findByRole("button", { name: "Pasife Al" }));

    expect(updateAccount).toHaveBeenCalledWith(1, { is_active: false });
  });
});
