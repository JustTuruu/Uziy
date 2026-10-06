import type { BadgeTone } from "@uziy/ui";
import type { Campaign, Payment, PaymentStatus } from "./api";
import { isCampaignPaid } from "./campaign-status";

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
  payable: number;
  targetViewers: number;
  rewardPerViewer: number;
  rewardsTotal: number;
  commissionTotal: number;
  commissionPercent: number | null;
}

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
  totalPaid: number;
  paidCount: number;
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
  awaitingPaymentTotal: number;
  totalSpent: number;
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
