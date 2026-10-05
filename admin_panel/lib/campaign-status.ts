import type { BadgeTone } from "@/components/ui/badge";
import type { CampaignStatus } from "./api";

export const CAMPAIGN_STATUS_LABEL: Record<CampaignStatus, string> = {
  AWAITING_PAYMENT: "Төлбөр хүлээгдэж буй",
  PENDING: "Хянагдаж буй",
  ACTIVE: "Идэвхтэй",
  PAUSED: "Түр зогсоосон",
  COMPLETED: "Дууссан",
  REJECTED: "Татгалзсан",
};

export const CAMPAIGN_STATUS_TONE: Record<CampaignStatus, BadgeTone> = {
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

export type CompanySettableStatus = "ACTIVE" | "PAUSED" | "COMPLETED";

const COMPANY_TRANSITIONS: Partial<
  Record<CampaignStatus, readonly CompanySettableStatus[]>
> = {
  ACTIVE: ["PAUSED", "COMPLETED"],
  PAUSED: ["ACTIVE", "COMPLETED"],
};

export function companyStatusTransitions(
  from: CampaignStatus,
): readonly CompanySettableStatus[] {
  return COMPANY_TRANSITIONS[from] ?? [];
}

export function canCompanySetStatus(
  from: CampaignStatus,
  to: CampaignStatus,
): boolean {
  return (companyStatusTransitions(from) as readonly CampaignStatus[]).includes(
    to,
  );
}

export function isCampaignPaid(status: CampaignStatus): boolean {
  return status !== "AWAITING_PAYMENT";
}
