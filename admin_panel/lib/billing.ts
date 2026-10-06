import type { Campaign } from "./api";
import { isCampaignPaid } from "./campaign-status";

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
