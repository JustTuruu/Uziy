import type { BadgeTone } from "@uziy/ui";
import type { CampaignStatus } from "./api";

const CAMPAIGN_STATUS_LABEL: Record<CampaignStatus, string> = {
  AWAITING_PAYMENT: "Төлбөр хүлээгдэж буй",
  PENDING: "Хянагдаж буй",
  ACTIVE: "Идэвхтэй",
  PAUSED: "Түр зогсоосон",
  COMPLETED: "Дууссан",
  REJECTED: "Татгалзсан",
};

const CAMPAIGN_STATUS_TONE: Record<CampaignStatus, BadgeTone> = {
  AWAITING_PAYMENT: "warning",
  PENDING: "info",
  ACTIVE: "success",
  PAUSED: "neutral",
  COMPLETED: "neutral",
  REJECTED: "danger",
};

export function campaignStatusLabel(status: CampaignStatus): string {
  return CAMPAIGN_STATUS_LABEL[status] ?? status;
}

export function campaignStatusTone(status: CampaignStatus): BadgeTone {
  return CAMPAIGN_STATUS_TONE[status] ?? "neutral";
}

export function isCampaignPaid(status: CampaignStatus): boolean {
  return status !== "AWAITING_PAYMENT";
}
