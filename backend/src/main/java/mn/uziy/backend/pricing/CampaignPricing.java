package mn.uziy.backend.pricing;

import org.jspecify.annotations.Nullable;

/**
 * Campaign pricing — the single source of truth for how a company's budget
 * is split between viewers and the platform.
 *
 * <p>MUST stay byte-for-byte equivalent to {@code company_panel/lib/pricing.ts}: the
 * wizard previews with the TS copy, the server recomputes with this one and
 * the server's numbers are what get saved and charged. Both suites carry the
 * same test vectors (V1–V10).
 *
 * <p>Integer arithmetic only (whole tögrög, {@code long}), no floating percentages:
 * <ul>
 *   <li>VIEWERS mode (company typed the viewer count N):
 *       costPerViewer C = floor(B / N); rewardPerViewer R = floor(C * (100 - c) / 100)</li>
 *   <li>REWARD mode (company typed the per-viewer reward R):
 *       costPerViewer C = ceil(R * 100 / (100 - c)); targetViewers N = floor(B / C)</li>
 * </ul>
 * payable P = C * N (never more than B; the remainder B - P is not charged),
 * commissionTotal = (C - R) * N, rewardsTotal = R * N.
 *
 * <p>The multiplications by {@code (100 - c)} / {@code 100} are done via a quotient +
 * remainder split so no intermediate product can overflow a long; the
 * results are identical to the naive formulas above.
 */
public final class CampaignPricing {

    public static final int MIN_COMMISSION_PERCENT = 1;
    public static final int MAX_COMMISSION_PERCENT = 90;

    private CampaignPricing() {
    }

    /**
     * @param mode               which input drives the pricing
     * @param budget             B, whole ₮ the company is willing to spend
     * @param commissionPercent  c, platform cut in percent (1..90)
     * @param minRewardPerViewer m, the admin-set floor for R (>= 1)
     * @param targetViewers      N — required (and only read) in VIEWERS mode
     * @param rewardPerViewer    R — required (and only read) in REWARD mode
     */
    public static PricingResult compute(
            PricingMode mode,
            long budget,
            int commissionPercent,
            long minRewardPerViewer,
            @Nullable Long targetViewers,
            @Nullable Long rewardPerViewer) {
        if (commissionPercent < MIN_COMMISSION_PERCENT || commissionPercent > MAX_COMMISSION_PERCENT) {
            throw new IllegalArgumentException("commissionPercent must be " + MIN_COMMISSION_PERCENT
                    + ".." + MAX_COMMISSION_PERCENT + ", was " + commissionPercent);
        }
        if (minRewardPerViewer < 1) {
            throw new IllegalArgumentException("minRewardPerViewer must be >= 1, was " + minRewardPerViewer);
        }

        final int c = commissionPercent;
        final long keep = 100 - c; // viewer share, in percent (10..99)

        if (budget < 1) {
            return result(mode, budget, c, 0, 0, 0, PricingError.BUDGET_INVALID);
        }

        if (mode == PricingMode.VIEWERS) {
            long n = targetViewers != null ? targetViewers : 0;
            if (n < 1) {
                return result(mode, budget, c, 0, 0, 0, PricingError.VIEWERS_INVALID);
            }
            long cost = budget / n;
            // floor(cost * keep / 100) without overflow.
            long reward = (cost / 100) * keep + ((cost % 100) * keep) / 100;
            PricingError error = null;
            if (cost < 1) {
                error = PricingError.BUDGET_TOO_SMALL;
            } else if (reward < minRewardPerViewer) {
                error = PricingError.REWARD_BELOW_MIN;
            }
            return result(mode, budget, c, n, cost, reward, error);
        }

        long reward = rewardPerViewer != null ? rewardPerViewer : 0;
        if (reward < 1) {
            return result(mode, budget, c, 0, 0, 0, PricingError.REWARD_INVALID);
        }
        // Only reachable for R in the quintillions: C itself doesn't fit in a
        // long, so it certainly exceeds any long budget.
        Long costOrNull = ceilCost(reward, keep);
        if (costOrNull == null) {
            return result(mode, budget, c, 0, 0, reward, PricingError.BUDGET_TOO_SMALL);
        }
        long cost = costOrNull;
        long n = budget / cost;
        PricingError error = null;
        if (n < 1) {
            error = PricingError.BUDGET_TOO_SMALL;
        } else if (reward < minRewardPerViewer) {
            error = PricingError.REWARD_BELOW_MIN;
        }
        return result(mode, budget, c, n, cost, reward, error);
    }

    /** Convenience for VIEWERS mode. */
    public static PricingResult forViewers(
            long budget, long targetViewers, int commissionPercent, long minRewardPerViewer) {
        return compute(PricingMode.VIEWERS, budget, commissionPercent, minRewardPerViewer,
                targetViewers, null);
    }

    /** Convenience for REWARD mode. */
    public static PricingResult forReward(
            long budget, long rewardPerViewer, int commissionPercent, long minRewardPerViewer) {
        return compute(PricingMode.REWARD, budget, commissionPercent, minRewardPerViewer,
                null, rewardPerViewer);
    }

    /**
     * ceil(reward * 100 / keep), computed as reward = q*keep + r so that
     * ceil = q*100 + ceil(r*100 / keep) — exact, and {@code null} instead of a
     * silently wrapped value if the true result doesn't fit in a long.
     */
    private static @Nullable Long ceilCost(long reward, long keep) {
        long q = reward / keep;
        long r = reward % keep;
        try {
            return Math.addExact(Math.multiplyExact(q, 100L), (r * 100 + keep - 1) / keep);
        } catch (ArithmeticException e) {
            return null;
        }
    }

    private static PricingResult result(
            PricingMode mode,
            long budget,
            int commissionPercent,
            long n,
            long cost,
            long reward,
            @Nullable PricingError error) {
        // Totals are only meaningful when at least one viewer is bought.
        long payable = (n > 0 && cost > 0) ? cost * n : 0;
        long rewardsTotal = payable > 0 ? reward * n : 0;
        long commissionTotal = payable > 0 ? (cost - reward) * n : 0;
        return new PricingResult(
                mode, budget, n, cost, reward, commissionPercent,
                payable, commissionTotal, rewardsTotal,
                budget > 0 ? budget - payable : 0,
                error);
    }
}
