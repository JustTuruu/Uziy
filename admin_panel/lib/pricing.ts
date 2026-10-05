import { formatNumber, formatTugrik } from "./utils";

export const MAX_MONEY_DIGITS = 13;

export type PricingMode = "VIEWERS" | "REWARD";

export type PricingErrorCode =
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

export function pricingErrorMessage(
  code: PricingErrorCode,
  minRewardPerViewer: number,
): string {
  switch (code) {
    case "BUDGET_INVALID":
      return "Нийт төсвөө оруулна уу";
    case "VIEWERS_INVALID":
      return "Үзэгчийн тоогоо оруулна уу";
    case "REWARD_INVALID":
      return "Нэг үзэгчид олгох урамшууллаа оруулна уу";
    case "BUDGET_TOO_SMALL":
      return "Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү";
    case "REWARD_BELOW_MIN":
      return `Нэг үзэгчид олгох урамшуулал хамгийн багадаа ${formatNumber(
        minRewardPerViewer,
      )} ₮ байх ёстой`;
  }
}

export function describePricing(p: PricingResult): string | null {
  if (
    p.error === "BUDGET_INVALID" ||
    p.error === "VIEWERS_INVALID" ||
    p.error === "REWARD_INVALID" ||
    p.error === "BUDGET_TOO_SMALL"
  ) {
    return null;
  }
  if (p.mode === "VIEWERS") {
    return (
      `${formatTugrik(p.budget)} ÷ ${formatNumber(p.targetViewers)} үзэгч = ` +
      `${formatTugrik(p.costPerViewer)} / үзэгч → платформын ` +
      `${p.commissionPercent}% шимтгэлийн дараа үзэгч бүр ` +
      `${formatTugrik(p.rewardPerViewer)} авна.`
    );
  }
  return (
    `Үзэгч бүр ${formatTugrik(p.rewardPerViewer)} авна → платформын ` +
    `${p.commissionPercent}% шимтгэлтэй нийлээд нэг үзэгчийн зардал ` +
    `${formatTugrik(p.costPerViewer)} → ${formatTugrik(p.budget)} ÷ ` +
    `${formatTugrik(p.costPerViewer)} = ${formatNumber(p.targetViewers)} үзэгч.`
  );
}

export function pricingRequestFields(
  p: Pick<PricingResult, "mode" | "targetViewers" | "rewardPerViewer">,
): { targetViewers: number } | { rewardPerUser: number } {
  return p.mode === "VIEWERS"
    ? { targetViewers: p.targetViewers }
    : { rewardPerUser: p.rewardPerViewer };
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
