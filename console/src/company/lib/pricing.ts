import { formatNumber, formatTugrik } from "./utils";

/**
 * Campaign pricing — the TypeScript twin of the backend's
 * mn.uziy.backend.pricing.CampaignPricing. Both sides MUST produce identical
 * numbers for the same inputs (the server recomputes on create and its
 * values win), so this uses integer arithmetic only: no floating percent
 * math, every division is an exact floor/ceil on whole tögrög.
 *
 * The company enters a total budget B plus ONE of:
 *   - VIEWERS mode: how many viewers N to reach → reward per viewer is derived
 *   - REWARD mode:  how much each viewer R receives → reach N is derived
 * The platform keeps `commissionPercent` of every viewer's cost C.
 *
 * Inputs must stay below ~9e13 so intermediate products (x100) remain safe
 * integers; the wizard's fields cap their length (MAX_MONEY_DIGITS) for this.
 */

/** Max digits accepted by money / count fields feeding this module. */
export const MAX_MONEY_DIGITS = 13;

export type PricingMode = "VIEWERS" | "REWARD";

export type PricingErrorCode =
  | "BUDGET_INVALID"
  | "VIEWERS_INVALID"
  | "REWARD_INVALID"
  | "BUDGET_TOO_SMALL"
  | "REWARD_BELOW_MIN";

export interface PricingInput {
  /** Total budget the company is willing to spend, whole ₮. */
  budget: number;
  /** Platform commission, whole percent 1..90 (admin setting). */
  commissionPercent: number;
  /** Smallest reward a viewer may receive, whole ₮ >= 1 (admin setting). */
  minRewardPerViewer: number;
  mode: PricingMode;
  /** Driver value in VIEWERS mode. */
  targetViewers?: number;
  /** Driver value in REWARD mode, whole ₮. */
  rewardPerViewer?: number;
}

export interface PricingResult {
  mode: PricingMode;
  budget: number;
  /** N — how many viewers the campaign reaches. */
  targetViewers: number;
  /** C — what one viewer costs the company (reward + commission). */
  costPerViewer: number;
  /** R — what one viewer receives. */
  rewardPerViewer: number;
  commissionPercent: number;
  /** P = C × N — what the company is charged (never more than the budget). */
  payable: number;
  /** (C − R) × N — the platform's total cut. */
  commissionTotal: number;
  /** R × N — the total paid out to viewers. */
  rewardsTotal: number;
  /** B − P — part of the budget that is simply not charged. */
  unused: number;
  error: PricingErrorCode | null;
}

/**
 * floor(a / b) for non-negative safe integers. Exact: the correctly rounded
 * quotient of two integers below 2^53 can never round up across an integer
 * boundary, so Math.floor gives the true integer quotient (the test suite
 * cross-checks this against BigInt).
 */
function floorDiv(a: number, b: number): number {
  return Math.floor(a / b);
}

function isWhole(n: number | undefined): n is number {
  return typeof n === "number" && Number.isSafeInteger(n);
}

/**
 * Computes the full price breakdown. Never throws for bad user input —
 * problems come back as `error` (first match wins, in contract order) while
 * every value that could be computed is still filled in so the UI can show
 * it. Throws RangeError only for an impossible admin setting (a programmer
 * or data error, since the DB constrains both).
 */
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

/** User-facing Mongolian message for a pricing error (same text as the API). */
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

/**
 * One-line "how was this computed" explanation shown under the budget
 * summary. Returns null when there is nothing meaningful to explain.
 */
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

/**
 * The part of the create-campaign request that tells the server how to
 * price it: EXACTLY ONE of targetViewers / rewardPerUser, matching the
 * field the company typed in last. The server recomputes everything else.
 */
export function pricingRequestFields(
  p: Pick<PricingResult, "mode" | "targetViewers" | "rewardPerViewer">,
): { targetViewers: number } | { rewardPerUser: number } {
  return p.mode === "VIEWERS"
    ? { targetViewers: p.targetViewers }
    : { rewardPerUser: p.rewardPerViewer };
}

