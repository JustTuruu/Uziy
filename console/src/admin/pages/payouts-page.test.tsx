import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { adminApi, auth, type Payout } from "@admin/lib/api";
import PayoutsPage from "./payouts-page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("@shared/navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@shared/navigation")>()),
  useRouter: () => router,
}));

const payout: Payout = {
  id: 1,
  userId: 7,
  userPhone: "88112233",
  amount: 2000,
  bank: "Khan Bank",
  accountNumber: "5001234567",
  accountName: "БОЛД ЭРДЭНЭ",
  status: "PENDING",
  isFirstPayout: true,
  requestedAt: new Date().toISOString(),
  decidedAt: null,
  rejectReason: null,
};

describe("Payout approval queue", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    window.localStorage.clear();
    auth.setToken("admin-token");
    vi.spyOn(adminApi, "pendingPayouts").mockResolvedValue([payout]);
    vi.spyOn(adminApi, "payoutHistory").mockResolvedValue([]);
  });

  it("shows a decided request's account masked, as the backend sends it", async () => {
    vi.spyOn(adminApi, "payoutHistory").mockResolvedValue([
      { ...payout, id: 2, status: "APPROVED", accountNumber: "•••• 4567", decidedAt: new Date().toISOString() },
    ]);
    render(<PayoutsPage />);

    expect(await screen.findByText("•••• 4567")).toBeTruthy();
    expect(screen.getByText(/сүүлийн 4 орон харагдана/)).toBeTruthy();
  });

  it("shows who asked, the account and the amount", async () => {
    render(<PayoutsPage />);

    expect(await screen.findByText("БОЛД ЭРДЭНЭ")).toBeTruthy();
    expect(screen.getByText("5001234567")).toBeTruthy();
  });

  /** The national ID is no longer collected (owner, 2026-10-14). */
  it("has no national ID column", async () => {
    render(<PayoutsPage />);
    await screen.findByText("БОЛД ЭРДЭНЭ");

    expect(screen.queryByRole("columnheader", { name: "Регистр" })).toBeNull();
    expect(screen.queryByText(/регистр/i)).toBeNull();
  });

  it("asks for the reject reason in an in-app dialog, not the browser's prompt", async () => {
    const nativePrompt = vi.fn();
    Object.defineProperty(window, "prompt", { value: nativePrompt, configurable: true, writable: true });
    const decide = vi
      .spyOn(adminApi, "decidePayout")
      .mockResolvedValue({ ...payout, status: "REJECTED", rejectReason: "Нэр таарахгүй", decidedAt: new Date().toISOString() });
    render(<PayoutsPage />);

    await userEvent.click(await screen.findByRole("button", { name: "Татгалзах" }));
    const dialog = screen.getByRole("alertdialog", { name: "Хүсэлтийг татгалзах уу?" });
    expect(dialog).toHaveTextContent("БОЛД ЭРДЭНЭ");
    const confirm = within(dialog).getByRole("button", { name: "Татгалзах" });
    expect(confirm).toBeDisabled();

    await userEvent.type(within(dialog).getByRole("textbox", { name: "Татгалзсан шалтгаан" }), " Нэр таарахгүй ");
    await userEvent.click(confirm);

    expect(nativePrompt).not.toHaveBeenCalled();
    expect(decide).toHaveBeenCalledWith(1, "REJECTED", "Нэр таарахгүй");
    expect(await screen.findByText("Татгалзсан")).toBeInTheDocument();
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  it("does nothing when the reject dialog is cancelled", async () => {
    const decide = vi.spyOn(adminApi, "decidePayout");
    render(<PayoutsPage />);

    await userEvent.click(await screen.findByRole("button", { name: "Татгалзах" }));
    await userEvent.click(within(screen.getByRole("alertdialog")).getByRole("button", { name: "Болих" }));

    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(decide).not.toHaveBeenCalled();
  });

  it("approves without a dialog", async () => {
    const decide = vi
      .spyOn(adminApi, "decidePayout")
      .mockResolvedValue({ ...payout, status: "APPROVED", decidedAt: new Date().toISOString() });
    render(<PayoutsPage />);

    await userEvent.click(await screen.findByRole("button", { name: "Батлах" }));

    expect(decide).toHaveBeenCalledWith(1, "APPROVED", undefined);
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });
});
