import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import WalletPage from "./Wallet";

vi.mock("../api/wallet", () => ({
  fetchWalletSummary: vi.fn()
}));

import { fetchWalletSummary } from "../api/wallet";

describe("WalletPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders simplified wallet summary with dedicated card and account sections", async () => {
    fetchWalletSummary.mockResolvedValue({
      liquid_balance: "30500.00",
      total_card_available: "16000.00",
      total_card_used: "24000.00",
      total_credit_limit: "40000.00",
      net_worth: "6500.00",
      active_account_count: 3,
      active_card_count: 1,
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

    render(<WalletPage />);

    expect(await screen.findByText("Ana Toplam")).toBeInTheDocument();
    expect(screen.getByText("Gelir")).toBeInTheDocument();
    expect(screen.getByText("Gider")).toBeInTheDocument();
    expect(screen.getByText("Kartlarini izle")).toBeInTheDocument();
    expect(screen.getByText("Hesaplarini izle")).toBeInTheDocument();
    expect(screen.getAllByText("Akbank Platinum").length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText("Enpara").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText("₺5.000,00")).toBeInTheDocument();
    expect(screen.getByText("₺2.000,00")).toBeInTheDocument();
    expect(screen.queryByText("Kart Durumu")).not.toBeInTheDocument();
    expect(screen.queryByText("Hesap Durumu")).not.toBeInTheDocument();
    expect(screen.queryByText("Kart Bilgileri")).not.toBeInTheDocument();
    expect(screen.queryByText("Bu Ay Giden")).not.toBeInTheDocument();
    expect(screen.queryByText("Kullanilabilir Limit")).not.toBeInTheDocument();
    expect(screen.queryByText("Likit Para")).not.toBeInTheDocument();
  });

  it("navigates to management from wallet sections", async () => {
    fetchWalletSummary.mockResolvedValue({
      liquid_balance: "1000.00",
      net_worth: "6500.00",
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
          statement_day: 25,
          due_day: 5,
          issuer: "Akbank",
          is_active: true
        }
      ]
    });

    const onNavigate = vi.fn();
    const user = userEvent.setup();

    render(<WalletPage onNavigate={onNavigate} />);

    await user.click(await screen.findByRole("button", { name: "Kart Yonet" }));

    expect(onNavigate).toHaveBeenCalledWith("manage");
  });
});
