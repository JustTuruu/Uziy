import { describe, expect, it } from "vitest";
import type { CampaignStatus } from "./api";
import {
  CAMPAIGN_STATUS_LABEL,
  campaignStatusLabel,
  campaignStatusTone,
  canCompanySetStatus,
  companyStatusTransitions,
  isCampaignPaid,
} from "./campaign-status";

const ALL: CampaignStatus[] = [
  "AWAITING_PAYMENT",
  "PENDING",
  "ACTIVE",
  "PAUSED",
  "COMPLETED",
  "REJECTED",
];

describe("campaign status labels", () => {
  it("labels every status in Mongolian", () => {
    expect(campaignStatusLabel("AWAITING_PAYMENT")).toBe("Төлбөр хүлээгдэж буй");
    expect(campaignStatusLabel("PENDING")).toBe("Хянагдаж буй");
    expect(campaignStatusLabel("ACTIVE")).toBe("Идэвхтэй");
    expect(campaignStatusLabel("PAUSED")).toBe("Түр зогсоосон");
    expect(campaignStatusLabel("COMPLETED")).toBe("Дууссан");
    expect(campaignStatusLabel("REJECTED")).toBe("Татгалзсан");
  });

  it("uses distinct labels so AWAITING_PAYMENT and PENDING cannot be confused", () => {
    const labels = ALL.map((s) => CAMPAIGN_STATUS_LABEL[s]);
    expect(new Set(labels).size).toBe(ALL.length);
  });

  it("maps tones: payment = warning, review = info, live = success, rejected = danger", () => {
    expect(campaignStatusTone("AWAITING_PAYMENT")).toBe("warning");
    expect(campaignStatusTone("PENDING")).toBe("info");
    expect(campaignStatusTone("ACTIVE")).toBe("success");
    expect(campaignStatusTone("PAUSED")).toBe("neutral");
    expect(campaignStatusTone("COMPLETED")).toBe("neutral");
    expect(campaignStatusTone("REJECTED")).toBe("danger");
  });

  it("falls back gracefully for an unknown status from a newer backend", () => {
    const unknown = "ARCHIVED" as CampaignStatus;
    expect(campaignStatusLabel(unknown)).toBe("ARCHIVED");
    expect(campaignStatusTone(unknown)).toBe("neutral");
  });
});

describe("company status transitions", () => {
  it("allows pause/complete from ACTIVE and resume/complete from PAUSED", () => {
    expect(companyStatusTransitions("ACTIVE")).toEqual(["PAUSED", "COMPLETED"]);
    expect(companyStatusTransitions("PAUSED")).toEqual(["ACTIVE", "COMPLETED"]);
  });

  it("allows nothing from unpaid, under-review, finished or rejected campaigns", () => {
    for (const s of ["AWAITING_PAYMENT", "PENDING", "COMPLETED", "REJECTED"] as const) {
      expect(companyStatusTransitions(s)).toEqual([]);
    }
  });

  it("closes the moderation bypass: PENDING → ACTIVE is not allowed", () => {
    expect(canCompanySetStatus("PENDING", "ACTIVE")).toBe(false);
    expect(canCompanySetStatus("AWAITING_PAYMENT", "ACTIVE")).toBe(false);
  });

  it("canCompanySetStatus agrees with the transition table", () => {
    for (const from of ALL) {
      for (const to of ALL) {
        const expected = (companyStatusTransitions(from) as readonly string[]).includes(to);
        expect(canCompanySetStatus(from, to)).toBe(expected);
      }
    }
    expect(canCompanySetStatus("ACTIVE", "PAUSED")).toBe(true);
    expect(canCompanySetStatus("PAUSED", "ACTIVE")).toBe(true);
    expect(canCompanySetStatus("PAUSED", "COMPLETED")).toBe(true);
    expect(canCompanySetStatus("ACTIVE", "ACTIVE")).toBe(false);
  });
});

describe("isCampaignPaid", () => {
  it("is false only while awaiting payment", () => {
    expect(isCampaignPaid("AWAITING_PAYMENT")).toBe(false);
    for (const s of ALL.filter((x) => x !== "AWAITING_PAYMENT")) {
      expect(isCampaignPaid(s)).toBe(true);
    }
  });
});
