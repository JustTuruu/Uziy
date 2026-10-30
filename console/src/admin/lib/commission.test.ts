import { describe, expect, it } from "vitest";
import { aCampaign } from "@shared/test/fixtures";
import { COMMISSION_RANGE_MESSAGE, LEGACY_CAMPAIGN_MESSAGE, rewardBelowMinMessage, splitAt } from "./commission";

/** Paid 1,000 ₮ per viewer for 1,000 viewers at 30 %. */
const paid = aCampaign({ costPerView: 1_000, targetViewers: 1_000, commissionPercent: 30, rewardPerUser: 700 });

describe("splitAt", () => {
  it("re-splits what was paid: a higher commission, a lower reward, the same totals", () => {
    expect(splitAt(paid, 40, 100)).toEqual({
      rewardPerViewer: 600,
      rewardsTotal: 600_000,
      commissionTotal: 400_000,
      error: null,
    });
  });

  it("refuses a percentage that leaves the viewer under the minimum", () => {
    expect(splitAt(paid, 40, 650).error).toBe(rewardBelowMinMessage(650));
  });

  it("refuses a percentage outside 1–90", () => {
    expect(splitAt(paid, 0, 100).error).toBe(COMMISSION_RANGE_MESSAGE);
    expect(splitAt(paid, 91, 100).error).toBe(COMMISSION_RANGE_MESSAGE);
  });

  it("cannot re-split a campaign of the old price model", () => {
    expect(splitAt({ ...paid, commissionPercent: null }, 30, 100).error).toBe(LEGACY_CAMPAIGN_MESSAGE);
  });
});
