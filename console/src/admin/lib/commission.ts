import type { Campaign } from "./api";
import { computeCampaignPricing, MAX_COMMISSION_PERCENT, MIN_COMMISSION_PERCENT } from "./pricing";

/** Same words as the backend (CommissionRange.MESSAGE). */
export const COMMISSION_RANGE_MESSAGE = `Платформын шимтгэл ${MIN_COMMISSION_PERCENT}–${MAX_COMMISSION_PERCENT}% хооронд байх ёстой`;
/** Same words as the backend (CampaignCommission.LEGACY_MESSAGE). */
export const LEGACY_CAMPAIGN_MESSAGE = "Хуучин үнийн загвартай судалгааны шимтгэлийг өөрчлөх боломжгүй";

export function rewardBelowMinMessage(minRewardPerViewer: number): string {
  return `Нэг үзэгчид олгох урамшуулал хамгийн багадаа ${minRewardPerViewer} ₮ байх ёстой`;
}

export interface CommissionSplit {
  rewardPerViewer: number;
  rewardsTotal: number;
  commissionTotal: number;
  /** Why this percentage cannot be used; null when it can. */
  error: string | null;
}

/**
 * What a paid campaign looks like approved at `percent` (owner, 2026-10-30): the company paid the cost per viewer
 * C for N viewers and both stay; only C's split changes. Mirrors the backend's CampaignCommission, so the admin
 * sees the reward before approving.
 */
export function splitAt(campaign: Campaign, percent: number, minRewardPerViewer: number): CommissionSplit {
  const empty = { rewardPerViewer: 0, rewardsTotal: 0, commissionTotal: 0 };
  if (!Number.isInteger(percent) || percent < MIN_COMMISSION_PERCENT || percent > MAX_COMMISSION_PERCENT) {
    return { ...empty, error: COMMISSION_RANGE_MESSAGE };
  }
  const viewers = campaign.targetViewers;
  if (viewers === null || viewers < 1 || campaign.commissionPercent === null) {
    return { ...empty, error: LEGACY_CAMPAIGN_MESSAGE };
  }
  const result = computeCampaignPricing({
    budget: campaign.costPerView * viewers,
    commissionPercent: percent,
    minRewardPerViewer,
    mode: "VIEWERS",
    targetViewers: viewers,
  });
  return {
    rewardPerViewer: result.rewardPerViewer,
    rewardsTotal: result.rewardsTotal,
    commissionTotal: result.commissionTotal,
    error: result.error === null ? null : rewardBelowMinMessage(minRewardPerViewer),
  };
}
