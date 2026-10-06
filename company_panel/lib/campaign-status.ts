import type { BadgeTone } from "@uziy/ui";
import type { CampaignStatus } from "./api";

/**
 * Single source of truth for how a campaign status is labelled and coloured
 * in both the company and the admin panels, and which status changes a
 * company may make itself.
 *
 * Lifecycle: create → AWAITING_PAYMENT → (company pays) → PENDING (paid,
 * awaiting admin moderation) → ACTIVE | REJECTED. After that the company can
 * pause / resume / complete; everything else is admin-only.
 */

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

/** Statuses a company may set on its own campaign via PATCH …/status. */
export type CompanySettableStatus = "ACTIVE" | "PAUSED" | "COMPLETED";

const COMPANY_TRANSITIONS: Partial<
  Record<CampaignStatus, readonly CompanySettableStatus[]>
> = {
  ACTIVE: ["PAUSED", "COMPLETED"],
  PAUSED: ["ACTIVE", "COMPLETED"],
};

/**
 * What the company may switch this campaign to (mirrors the backend rule:
 * ACTIVE→PAUSED, PAUSED→ACTIVE, ACTIVE|PAUSED→COMPLETED; nothing else).
 */
export function companyStatusTransitions(
  from: CampaignStatus,
): readonly CompanySettableStatus[] {
  return COMPANY_TRANSITIONS[from] ?? [];
}

/** A campaign whose money has been received (paid or legacy pre-payment). */
export function isCampaignPaid(status: CampaignStatus): boolean {
  return status !== "AWAITING_PAYMENT";
}
