import { describe, expect, it } from "vitest";
import type { CampaignStatus } from "./api";
import {
  canEditCover,
  campaignStatusLabel,
  campaignStatusTone,
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
    const labels = ALL.map((s) => campaignStatusLabel(s));
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

describe("isCampaignPaid", () => {
  it("is false only while awaiting payment", () => {
    expect(isCampaignPaid("AWAITING_PAYMENT")).toBe(false);
    for (const s of ALL.filter((x) => x !== "AWAITING_PAYMENT")) {
      expect(isCampaignPaid(s)).toBe(true);
    }
  });
});

describe("canEditCover", () => {
  it("allows the cover before approval only", () => {
    expect(canEditCover("AWAITING_PAYMENT")).toBe(true);
    expect(canEditCover("PENDING")).toBe(true);
    for (const s of ["ACTIVE", "PAUSED", "COMPLETED", "REJECTED"] as const) {
      expect(canEditCover(s)).toBe(false);
    }
  });
});
