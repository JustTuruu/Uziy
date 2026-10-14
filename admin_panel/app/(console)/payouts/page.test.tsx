import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { adminApi, auth, type Payout } from "@/lib/api";
import PayoutsPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

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
});
