import type { BadgeTone } from "@uziy/ui";
import type { Campaign, Payment, PaymentStatus } from "./api";
import { isCampaignPaid } from "./campaign-status";

/**
 * Billing helpers for the company panel. There is no account balance /
 * top-up concept: every campaign is paid for on its own, once, right after
 * it is created.
 */

export const PAYMENT_STATUS_LABEL: Record<PaymentStatus, string> = {
  PAID: "Төлөгдсөн",
  FAILED: "Амжилтгүй",
  REFUNDED: "Буцаагдсан",
};

export const PAYMENT_STATUS_TONE: Record<PaymentStatus, BadgeTone> = {
  PAID: "success",
  FAILED: "danger",
  REFUNDED: "neutral",
};

export interface CampaignInvoice {
  /** What the company is charged — the campaign's (server-computed) budget. */
  payable: number;
  targetViewers: number;
  rewardPerViewer: number;
  /** Paid out to viewers in total. */
  rewardsTotal: number;
  /** Platform's cut; payable − rewardsTotal so the lines always add up. */
  commissionTotal: number;
  commissionPercent: number | null;
}

/**
 * Invoice breakdown for one campaign, built only from server-returned
 * values (the server priced it; the client never re-derives the price).
 */
export function campaignInvoice(c: Campaign): CampaignInvoice {
  const targetViewers =
    c.targetViewers ??
    (c.costPerView > 0 ? Math.floor(c.totalBudget / c.costPerView) : 0);
  const payable = c.totalBudget;
  const rewardsTotal = c.rewardPerUser * targetViewers;
  return {
    payable,
    targetViewers,
    rewardPerViewer: c.rewardPerUser,
    rewardsTotal,
    commissionTotal: Math.max(0, payable - rewardsTotal),
    commissionPercent: c.commissionPercent,
  };
}

export interface PaymentSummary {
  /** Sum of PAID payments. */
  totalPaid: number;
  paidCount: number;
  /** ISO timestamp of the most recent PAID payment, or null. */
  lastPaidAt: string | null;
}

export function summarizePayments(payments: Payment[]): PaymentSummary {
  let totalPaid = 0;
  let paidCount = 0;
  let lastPaidAt: string | null = null;
  let lastMs = -Infinity;
  for (const p of payments) {
    if (p.status !== "PAID") continue;
    totalPaid += p.amount;
    paidCount += 1;
    const at = p.paidAt ?? p.createdAt;
    const ms = Date.parse(at);
    if (Number.isFinite(ms) && ms > lastMs) {
      lastMs = ms;
      lastPaidAt = at;
    }
  }
  return { totalPaid, paidCount, lastPaidAt };
}

export interface CampaignBudgetSummary {
  activeCount: number;
  awaitingPayment: Campaign[];
  /** Sum still owed on AWAITING_PAYMENT campaigns. */
  awaitingPaymentTotal: number;
  /** Spent so far on paid campaigns. */
  totalSpent: number;
  /** Not yet spent on paid campaigns (unpaid campaigns are excluded). */
  totalRemaining: number;
}

export function summarizeCampaignBudgets(
  campaigns: Campaign[],
): CampaignBudgetSummary {
  const summary: CampaignBudgetSummary = {
    activeCount: 0,
    awaitingPayment: [],
    awaitingPaymentTotal: 0,
    totalSpent: 0,
    totalRemaining: 0,
  };
  for (const c of campaigns) {
    if (c.status === "ACTIVE") summary.activeCount += 1;
    if (!isCampaignPaid(c.status)) {
      summary.awaitingPayment.push(c);
      summary.awaitingPaymentTotal += c.totalBudget;
      continue;
    }
    summary.totalSpent += c.totalBudget - c.remainingBudget;
    summary.totalRemaining += c.remainingBudget;
  }
  return summary;
}
