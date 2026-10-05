import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { auth, companyApi, type Campaign, type Payment } from "@/lib/api";
import { formatDate, formatTugrik } from "@/lib/utils";
import BillingPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

function campaign(over: Partial<Campaign>): Campaign {
  return {
    id: 1,
    title: "Аян",
    videoUrl: "",
    durationSeconds: 0,
    hasVideo: false,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 45,
    targetCity: "ALL",
    totalBudget: 1_000_000,
    remainingBudget: 1_000_000,
    costPerView: 1_000,
    rewardPerUser: 700,
    targetViewers: 1_000,
    commissionPercent: 30,
    paidAt: null,
    status: "ACTIVE",
    createdAt: "2026-09-01T00:00:00Z",
    ...over,
  };
}

function payment(over: Partial<Payment>): Payment {
  return {
    id: 1,
    campaignId: 1,
    campaignTitle: "Аян",
    amount: 1_000_000,
    provider: "SIMULATED",
    status: "PAID",
    reference: "UZ-20260901-1",
    createdAt: "2026-09-01T00:00:00Z",
    paidAt: "2026-09-01T00:00:00Z",
    ...over,
  };
}

beforeEach(() => {
  vi.spyOn(auth, "getToken").mockReturnValue("company-tok");
  router.replace.mockReset();
});
afterEach(() => vi.restoreAllMocks());

describe("Company billing page", () => {
  it("has no top-up / account-balance concept any more", async () => {
    vi.spyOn(companyApi, "payments").mockResolvedValue([]);
    vi.spyOn(companyApi, "list").mockResolvedValue([]);
    render(<BillingPage />);
    expect(await screen.findByText("Одоогоор төлбөр хийгдээгүй байна.")).toBeInTheDocument();
    expect(screen.queryByText(/Данс цэнэглэх/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Дансны үлдэгдэл/)).not.toBeInTheDocument();
    expect(screen.getByText("Аян тус бүрийн төлбөрөө энд хянана")).toBeInTheDocument();
  });

  it("shows totals, awaiting-payment campaigns and the payment history", async () => {
    vi.spyOn(companyApi, "payments").mockResolvedValue([
      payment({
        id: 2,
        campaignId: 5,
        campaignTitle: "5G багц",
        amount: 999_570,
        reference: "UZ-20260920-5",
        paidAt: "2026-09-20T08:00:00Z",
      }),
      payment({ id: 1, amount: 500_000 }),
    ]);
    vi.spyOn(companyApi, "list").mockResolvedValue([
      campaign({ id: 9, title: "Намрын хямдрал", status: "AWAITING_PAYMENT", totalBudget: 400_000 }),
      campaign({ id: 5, title: "5G багц", status: "PENDING" }),
    ]);

    render(<BillingPage />);

    expect(await screen.findByText("UZ-20260920-5")).toBeInTheDocument();
    expect(screen.getByText(formatTugrik(1_499_570))).toBeInTheDocument(); // Нийт төлсөн
    // "Сүүлийн төлбөр" stat + the history row.
    expect(screen.getAllByText(formatDate("2026-09-20T08:00:00Z"))).toHaveLength(2);
    expect(screen.getByRole("link", { name: "5G багц" })).toHaveAttribute(
      "href",
      "/campaigns/5",
    );
    expect(screen.getAllByText("Төлөгдсөн")).toHaveLength(2);

    // Awaiting-payment campaign with a pay link.
    expect(screen.getByText("Намрын хямдрал")).toBeInTheDocument();
    const payLinks = screen.getAllByRole("link", { name: /Төлөх/ });
    expect(payLinks.map((a) => a.getAttribute("href"))).toContain("/campaigns/9");
  });

  it("shows an error state when loading fails", async () => {
    vi.spyOn(companyApi, "payments").mockRejectedValue(new Error("Сүлжээний алдаа"));
    vi.spyOn(companyApi, "list").mockResolvedValue([]);
    render(<BillingPage />);
    expect(await screen.findByRole("alert")).toHaveTextContent("Сүлжээний алдаа");
  });
});
