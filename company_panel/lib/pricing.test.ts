import { describe, expect, it } from "vitest";
import {
  computeCampaignPricing,
  describePricing,
  pricingErrorMessage,
  pricingRequestFields,
  type PricingInput,
} from "./pricing";
import { formatTugrik } from "./utils";

const base = { commissionPercent: 30, minRewardPerViewer: 100 };

function viewers(budget: number, targetViewers: number, over: Partial<PricingInput> = {}) {
  return computeCampaignPricing({ ...base, budget, mode: "VIEWERS", targetViewers, ...over });
}
function reward(budget: number, rewardPerViewer: number, over: Partial<PricingInput> = {}) {
  return computeCampaignPricing({ ...base, budget, mode: "REWARD", rewardPerViewer, ...over });
}

describe("computeCampaignPricing — shared contract vectors", () => {
  it("V1 VIEWERS 1,000,000 ₮ / 1,000 viewers at 30%", () => {
    expect(viewers(1_000_000, 1_000)).toEqual({
      mode: "VIEWERS",
      budget: 1_000_000,
      targetViewers: 1_000,
      costPerViewer: 1_000,
      rewardPerViewer: 700,
      commissionPercent: 30,
      payable: 1_000_000,
      commissionTotal: 300_000,
      rewardsTotal: 700_000,
      unused: 0,
      error: null,
    });
  });

  it("V2 VIEWERS 1,000,000 ₮ / 1,428 viewers leaves 400 ₮ uncharged", () => {
    const p = viewers(1_000_000, 1_428);
    expect(p).toMatchObject({
      costPerViewer: 700,
      rewardPerViewer: 490,
      payable: 999_600,
      unused: 400,
      error: null,
    });
  });

  it("V3 REWARD 700 ₮ per viewer on 1,000,000 ₮", () => {
    expect(reward(1_000_000, 700)).toMatchObject({
      costPerViewer: 1_000,
      targetViewers: 1_000,
      payable: 1_000_000,
      error: null,
    });
  });

  it("V4 REWARD 500 ₮ per viewer rounds the cost UP", () => {
    // NOTE: the contract text lists commissionTotal = 300,630 here, but its
    // own formula (C − R) × N = (715 − 500) × 1,398 = 300,570, which also
    // equals P − rewardsTotal = 999,570 − 699,000. We assert the formula.
    expect(reward(1_000_000, 500)).toMatchObject({
      costPerViewer: 715,
      targetViewers: 1_398,
      payable: 999_570,
      rewardsTotal: 699_000,
      commissionTotal: 300_570,
      unused: 430,
      error: null,
    });
  });

  it("V5 VIEWERS at a 35% commission", () => {
    expect(
      viewers(500_000, 1_000, { commissionPercent: 35 }),
    ).toMatchObject({ costPerViewer: 500, rewardPerViewer: 325, error: null });
  });

  it("V6 budget below one tögrög per viewer → BUDGET_TOO_SMALL", () => {
    expect(viewers(500, 1_000).error).toBe("BUDGET_TOO_SMALL");
  });

  it("V7 reward under the admin minimum → REWARD_BELOW_MIN", () => {
    const p = viewers(100_000, 1_000);
    expect(p).toMatchObject({ costPerViewer: 100, rewardPerViewer: 70 });
    expect(p.error).toBe("REWARD_BELOW_MIN");
  });

  it("V8 REWARD mode where the budget cannot cover one viewer", () => {
    const p = reward(500, 700);
    expect(p).toMatchObject({ costPerViewer: 1_000, targetViewers: 0 });
    expect(p.error).toBe("BUDGET_TOO_SMALL");
  });

  it("V9 empty inputs", () => {
    expect(viewers(0, 1_000).error).toBe("BUDGET_INVALID");
    expect(reward(0, 700).error).toBe("BUDGET_INVALID");
    expect(viewers(1_000_000, 0).error).toBe("VIEWERS_INVALID");
    expect(reward(1_000_000, 0).error).toBe("REWARD_INVALID");
  });

  it("V10 large budget stays exact (no overflow / float drift)", () => {
    expect(viewers(10_000_000_000, 3)).toMatchObject({
      costPerViewer: 3_333_333_333,
      rewardPerViewer: 2_333_333_333,
      payable: 9_999_999_999,
      unused: 1,
      error: null,
    });
  });
});

describe("computeCampaignPricing — details", () => {
  it("reports errors in contract order (budget before driver)", () => {
    expect(viewers(0, 0).error).toBe("BUDGET_INVALID");
    expect(reward(-5, 0).error).toBe("BUDGET_INVALID");
  });

  it("treats non-integers as invalid input", () => {
    expect(viewers(1_000.5, 10).error).toBe("BUDGET_INVALID");
    expect(viewers(1_000, 2.5).error).toBe("VIEWERS_INVALID");
    expect(reward(1_000, Number.NaN).error).toBe("REWARD_INVALID");
  });

  it("REWARD mode also enforces the minimum reward", () => {
    expect(reward(1_000_000, 50).error).toBe("REWARD_BELOW_MIN");
    expect(reward(1_000_000, 100).error).toBeNull();
  });

  it("matches exact BigInt arithmetic for 13-digit budgets", () => {
    const cases: [number, number, number][] = [
      [9_999_999_999_999, 10_000, 30],
      [9_999_999_999_999, 7, 1],
      [8_888_888_888_887, 999_999, 90],
      [1_234_567_890_123, 3, 33],
    ];
    for (const [B, N, c] of cases) {
      const p = viewers(B, N, { commissionPercent: c, minRewardPerViewer: 1 });
      const C = BigInt(B) / BigInt(N);
      const R = (C * BigInt(100 - c)) / BigInt(100);
      expect(BigInt(p.costPerViewer)).toBe(C);
      expect(BigInt(p.rewardPerViewer)).toBe(R);
      expect(BigInt(p.payable)).toBe(C * BigInt(N));

      const q = reward(B, Number(R), { commissionPercent: c, minRewardPerViewer: 1 });
      const denom = BigInt(100 - c);
      const C2 = (R * BigInt(100) + denom - BigInt(1)) / denom;
      expect(BigInt(q.costPerViewer)).toBe(C2);
      expect(BigInt(q.targetViewers)).toBe(BigInt(B) / C2);
    }
  });

  it("rejects impossible admin settings loudly", () => {
    expect(() => viewers(1_000, 1, { commissionPercent: 0 })).toThrow(RangeError);
    expect(() => viewers(1_000, 1, { commissionPercent: 91 })).toThrow(RangeError);
    expect(() => viewers(1_000, 1, { minRewardPerViewer: 0 })).toThrow(RangeError);
  });

  it("invariant: whenever there is no error, 1 <= R < C and P <= B", () => {
    // Deterministic pseudo-random sweep (mulberry32) so failures reproduce.
    let seed = 42;
    const rand = () => {
      seed = (seed + 0x6d2b79f5) | 0;
      let t = seed;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
    const int = (lo: number, hi: number) => lo + Math.floor(rand() * (hi - lo + 1));

    let checked = 0;
    for (let i = 0; i < 5_000; i++) {
      const input: PricingInput = {
        budget: int(1, 50_000_000),
        commissionPercent: int(1, 90),
        minRewardPerViewer: int(1, 1_000),
        mode: rand() < 0.5 ? "VIEWERS" : "REWARD",
        targetViewers: int(1, 100_000),
        rewardPerViewer: int(1, 20_000),
      };
      const p = computeCampaignPricing(input);
      if (p.error !== null) continue;
      checked++;
      expect(p.rewardPerViewer).toBeGreaterThanOrEqual(1);
      expect(p.rewardPerViewer).toBeLessThan(p.costPerViewer);
      expect(p.payable).toBeLessThanOrEqual(p.budget);
      expect(p.payable).toBe(p.costPerViewer * p.targetViewers);
      expect(p.commissionTotal + p.rewardsTotal).toBe(p.payable);
      expect(p.unused).toBe(p.budget - p.payable);
    }
    expect(checked).toBeGreaterThan(1_000);
  });
});

describe("pricingErrorMessage", () => {
  it("returns the shared Mongolian messages", () => {
    expect(pricingErrorMessage("BUDGET_INVALID", 100)).toBe("Нийт төсвөө оруулна уу");
    expect(pricingErrorMessage("VIEWERS_INVALID", 100)).toBe("Үзэгчийн тоогоо оруулна уу");
    expect(pricingErrorMessage("REWARD_INVALID", 100)).toBe(
      "Нэг үзэгчид олгох урамшууллаа оруулна уу",
    );
    expect(pricingErrorMessage("BUDGET_TOO_SMALL", 100)).toBe(
      "Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү",
    );
    expect(pricingErrorMessage("REWARD_BELOW_MIN", 100)).toBe(
      "Нэг үзэгчид олгох урамшуулал хамгийн багадаа 100 ₮ байх ёстой",
    );
  });
});

describe("describePricing", () => {
  it("explains VIEWERS mode as budget ÷ viewers minus commission", () => {
    expect(describePricing(viewers(1_000_000, 1_000))).toBe(
      `${formatTugrik(1_000_000)} ÷ 1,000 үзэгч = ${formatTugrik(1_000)} / үзэгч → ` +
        `платформын 30% шимтгэлийн дараа үзэгч бүр ${formatTugrik(700)} авна.`,
    );
  });

  it("explains REWARD mode as reward + commission → reach", () => {
    const text = describePricing(reward(1_000_000, 500));
    expect(text).toContain(`Үзэгч бүр ${formatTugrik(500)} авна`);
    expect(text).toContain(`нэг үзэгчийн зардал ${formatTugrik(715)}`);
    expect(text).toContain("= 1,398 үзэгч.");
  });

  it("stays quiet when inputs are missing or the budget is too small", () => {
    expect(describePricing(viewers(0, 1_000))).toBeNull();
    expect(describePricing(viewers(500, 1_000))).toBeNull();
  });

  it("still explains a below-minimum reward so the user sees why", () => {
    expect(describePricing(viewers(100_000, 1_000))).toContain(formatTugrik(70));
  });
});

describe("pricingRequestFields", () => {
  it("sends only targetViewers in VIEWERS mode", () => {
    expect(pricingRequestFields(viewers(1_000_000, 1_000))).toEqual({
      targetViewers: 1_000,
    });
  });

  it("sends only rewardPerUser in REWARD mode", () => {
    expect(pricingRequestFields(reward(1_000_000, 500))).toEqual({
      rewardPerUser: 500,
    });
  });
});

