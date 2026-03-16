import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import ManagePage from "./ManagePage";

vi.mock("../api/accounts", () => ({
  fetchAccounts: vi.fn(),
  createAccount: vi.fn(),
  updateAccount: vi.fn()
}));

vi.mock("../api/wallet", () => ({
  fetchWalletSummary: vi.fn()
}));

import { createAccount, fetchAccounts, updateAccount } from "../api/accounts";
import { fetchWalletSummary } from "../api/wallet";

describe("ManagePage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    fetchWalletSummary.mockResolvedValue({
      liquid_balance: "12000.00",
      total_card_used: "4000.00",
      net_worth: "8000.00"
    });
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
    expect(screen.getByText("Hesaplar ve Kartlar")).toBeInTheDocument();
    expect(screen.getByText("Akbank Platinum")).toBeInTheDocument();
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
