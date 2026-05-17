import { fireEvent, render, screen } from "@testing-library/react";
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

    expect(await screen.findByText("Cuzdanim")).toBeInTheDocument();
    expect(screen.getByText("Limit / Ekstre Paneli")).toBeInTheDocument();
    expect(screen.getByText("Aktif Ekstreler")).toBeInTheDocument();
    expect(screen.getAllByText("Kart Bilgileri").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByRole("button", { name: "Ayar" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Ayarlar" })).toBeInTheDocument();
    expect(screen.getAllByText("Akbank Platinum").length).toBeGreaterThanOrEqual(1);
  });

  it("creates a new account", async () => {
    createAccount.mockResolvedValue({ id: 2 });

    const user = userEvent.setup();
    render(<ManagePage />);

    await user.click(await screen.findByRole("button", { name: "+" }));
    await user.type(await screen.findByLabelText("Hesap Adi"), "Enpara");
    await user.type(screen.getByLabelText("Guncel Bakiye (₺)"), "2500");
    await user.click(screen.getByRole("button", { name: "Sisteme Ekle" }));

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

    await user.click(await screen.findByRole("button", { name: "Dondur" }));

    expect(updateAccount).toHaveBeenCalledWith(1, { is_active: false });
  });

  it("switches cards with swipe and keeps the selected statement visible", async () => {
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
      },
      {
        account_id: 2,
        account_name: "Bonus Gold",
        period_start: "2026-03-01",
        period_end: "2026-03-31",
        due_date: "2026-04-10",
        auto_resets_at: "2026-04-01T00:00:00+00:00",
        statement_amount: "1100.00",
        payment_activity: "200.00",
        transaction_count: 2
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
      },
      {
        id: 2,
        name: "Bonus Gold",
        type: "credit_card",
        currency: "TRY",
        balance: "7000.00",
        credit_limit: "20000.00",
        statement_day: 18,
        due_day: 10,
        issuer: "Garanti",
        is_active: true
      }
    ]);

    render(<ManagePage />);

    expect(await screen.findAllByText("Akbank Platinum")).not.toHaveLength(0);

    const focusedCard = document.querySelector(".manage-focused-card");
    expect(focusedCard).not.toBeNull();

    fireEvent.touchStart(focusedCard, {
      touches: [{ clientX: 200, clientY: 100 }]
    });
    fireEvent.touchMove(focusedCard, {
      touches: [{ clientX: 120, clientY: 102 }]
    });
    fireEvent.touchEnd(focusedCard, {
      changedTouches: [{ clientX: 120, clientY: 102 }]
    });

    expect(await screen.findAllByText("Bonus Gold")).not.toHaveLength(0);
    expect(screen.getAllByText("₺1.100,00")).not.toHaveLength(0);
    expect(screen.queryByText("₺2.500,00")).not.toBeInTheDocument();
  });
});
