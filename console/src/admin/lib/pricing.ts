type PricingMode = "VIEWERS" | "REWARD";

type PricingErrorCode =
  | "BUDGET_INVALID"
  | "VIEWERS_INVALID"
  | "REWARD_INVALID"
  | "BUDGET_TOO_SMALL"
  | "REWARD_BELOW_MIN";

export interface PricingInput {
  budget: number;
  commissionPercent: number;
  minRewardPerViewer: number;
  mode: PricingMode;
  targetViewers?: number;
  rewardPerViewer?: number;
}

export interface PricingResult {
  mode: PricingMode;
  budget: number;
  targetViewers: number;
  costPerViewer: number;
  rewardPerViewer: number;
  commissionPercent: number;
  payable: number;
  commissionTotal: number;
  rewardsTotal: number;
  unused: number;
  error: PricingErrorCode | null;
}

function floorDiv(a: number, b: number): number {
  return Math.floor(a / b);
}

function isWhole(n: number | undefined): n is number {
  return typeof n === "number" && Number.isSafeInteger(n);
}

export function computeCampaignPricing(input: PricingInput): PricingResult {
  const c = input.commissionPercent;
  const m = input.minRewardPerViewer;
  if (!isWhole(c) || c < 1 || c > 90) {
    throw new RangeError(`commissionPercent must be 1..90, got ${c}`);
  }
  if (!isWhole(m) || m < 1) {
    throw new RangeError(`minRewardPerViewer must be >= 1, got ${m}`);
  }

  const result: PricingResult = {
    mode: input.mode,
    budget: isWhole(input.budget) ? input.budget : 0,
    targetViewers: 0,
    costPerViewer: 0,
    rewardPerViewer: 0,
    commissionPercent: c,
    payable: 0,
    commissionTotal: 0,
    rewardsTotal: 0,
    unused: 0,
    error: null,
  };

  const B = input.budget;
  if (!isWhole(B) || B < 1) return { ...result, error: "BUDGET_INVALID" };

  let N: number;
  let C: number;
  let R: number;
  if (input.mode === "VIEWERS") {
    const n = input.targetViewers;
    if (!isWhole(n) || n < 1) return { ...result, error: "VIEWERS_INVALID" };
    N = n;
    C = floorDiv(B, N);
    R = floorDiv(C * (100 - c), 100);
  } else {
    const r = input.rewardPerViewer;
    if (!isWhole(r) || r < 1) return { ...result, error: "REWARD_INVALID" };
    R = r;
    // ceil(R * 100 / (100 - c)) in integer arithmetic.
    C = floorDiv(R * 100 + (100 - c) - 1, 100 - c);
    N = floorDiv(B, C);
  }

  const payable = C * N;
  const filled: PricingResult = {
    ...result,
    targetViewers: N,
    costPerViewer: C,
    rewardPerViewer: R,
    payable,
    commissionTotal: (C - R) * N,
    rewardsTotal: R * N,
    unused: B - payable,
  };

  const tooSmall = input.mode === "VIEWERS" ? C < 1 : N < 1;
  if (tooSmall) return { ...filled, error: "BUDGET_TOO_SMALL" };
  if (R < m) return { ...filled, error: "REWARD_BELOW_MIN" };
  return filled;
}

export const MIN_COMMISSION_PERCENT = 1;
export const MAX_COMMISSION_PERCENT = 90;

export function validateCommissionSettings(
  commissionPercent: number,
  minRewardPerViewer: number,
): string | null {
  if (
    !Number.isInteger(commissionPercent) ||
    commissionPercent < MIN_COMMISSION_PERCENT ||
    commissionPercent > MAX_COMMISSION_PERCENT
  ) {
    return `Платформын шимтгэл ${MIN_COMMISSION_PERCENT}–${MAX_COMMISSION_PERCENT}% хооронд байх ёстой`;
  }
  if (!Number.isInteger(minRewardPerViewer) || minRewardPerViewer < 1) {
    return "Нэг үзэгчид олгох хамгийн бага урамшуулал 1 ₮-с багагүй байх ёстой";
  }
  return null;
}
