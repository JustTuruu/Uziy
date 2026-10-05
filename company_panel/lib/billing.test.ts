import { describe, expect, it } from "vitest";
import type { Campaign, Payment } from "./api";
import {
  PAYMENT_STATUS_LABEL,
  campaignInvoice,
  summarizeCampaignBudgets,
  summarizePayments,
} from "./billing";

function campaign(over: Partial<Campaign> = {}): Campaign {
  return {
    id: 1,
    title: "Шинэ 5G багц",
    videoUrl: "",
    durationSeconds: 30,
    hasVideo: true,
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
    status: "AWAITING_PAYMENT",
    createdAt: "2026-09-28T10:00:00Z",
    ...over,
  };
}

function payment(over: Partial<Payment> = {}): Payment {
  return {
    id: 1,
    campaignId: 1,
    campaignTitle: "Шинэ 5G багц",
    amount: 1_000_000,
    provider: "SIMULATED",
    status: "PAID",
    reference: "UZ-20260928-1",
    createdAt: "2026-09-28T10:00:00Z",
    paidAt: "2026-09-28T10:00:05Z",
    ...over,
  };
}

describe("campaignInvoice", () => {
  it("splits the payable amount into viewer rewards and platform commission", () => {
    expect(campaignInvoice(campaign())).toEqual({
      payable: 1_000_000,
      targetViewers: 1_000,
      rewardPerViewer: 700,
      rewardsTotal: 700_000,
      commissionTotal: 300_000,
      commissionPercent: 30,
    });
  });

  it("uses the server's values as-is (V4: 999,570 ₮ for 1,398 viewers)", () => {
    const inv = campaignInvoice(
      campaign({
        totalBudget: 999_570,
        remainingBudget: 999_570,
        costPerView: 715,
        rewardPerUser: 500,
        targetViewers: 1_398,
      }),
    );
    expect(inv.payable).toBe(999_570);
    expect(inv.rewardsTotal).toBe(699_000);
    expect(inv.commissionTotal).toBe(300_570);
    expect(inv.rewardsTotal + inv.commissionTotal).toBe(inv.payable);
  });

  it("derives reach for legacy rows without targetViewers", () => {
    const inv = campaignInvoice(
      campaign({ targetViewers: null, commissionPercent: null, costPerView: 800 }),
    );
    expect(inv.targetViewers).toBe(1_250);
    expect(inv.commissionPercent).toBeNull();
  });
});

describe("summarizePayments", () => {
  it("sums only PAID payments and finds the latest one", () => {
    const s = summarizePayments([
      payment({ id: 1, amount: 500_000, paidAt: "2026-09-01T00:00:00Z" }),
      payment({ id: 2, amount: 1_000_000, paidAt: "2026-09-20T00:00:00Z" }),
      payment({ id: 3, amount: 9_999, status: "FAILED", paidAt: null, createdAt: "2026-09-27T00:00:00Z" }),
      payment({ id: 4, amount: 7_777, status: "REFUNDED", paidAt: "2026-09-25T00:00:00Z" }),
    ]);
    expect(s).toEqual({
      totalPaid: 1_500_000,
      paidCount: 2,
      lastPaidAt: "2026-09-20T00:00:00Z",
    });
  });

  it("is empty-safe", () => {
    expect(summarizePayments([])).toEqual({ totalPaid: 0, paidCount: 0, lastPaidAt: null });
  });

  it("falls back to createdAt when paidAt is missing", () => {
    expect(
      summarizePayments([payment({ paidAt: null, createdAt: "2026-09-10T00:00:00Z" })])
        .lastPaidAt,
    ).toBe("2026-09-10T00:00:00Z");
  });

  it("labels payment statuses in Mongolian", () => {
    expect(PAYMENT_STATUS_LABEL.PAID).toBe("Төлөгдсөн");
  });
});

describe("summarizeCampaignBudgets", () => {
  it("keeps unpaid campaigns out of spent/remaining and lists them separately", () => {
    const s = summarizeCampaignBudgets([
      campaign({ id: 1, status: "AWAITING_PAYMENT", totalBudget: 400_000, remainingBudget: 400_000 }),
      campaign({ id: 2, status: "ACTIVE", totalBudget: 1_000_000, remainingBudget: 300_000 }),
      campaign({ id: 3, status: "PENDING", totalBudget: 200_000, remainingBudget: 200_000 }),
      campaign({ id: 4, status: "ACTIVE", totalBudget: 100_000, remainingBudget: 0 }),
    ]);
    expect(s.activeCount).toBe(2);
    expect(s.awaitingPayment.map((c) => c.id)).toEqual([1]);
    expect(s.awaitingPaymentTotal).toBe(400_000);
    expect(s.totalSpent).toBe(700_000 + 100_000);
    expect(s.totalRemaining).toBe(300_000 + 200_000);
  });
});
