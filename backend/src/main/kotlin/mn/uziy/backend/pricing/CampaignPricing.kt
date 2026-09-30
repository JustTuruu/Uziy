package mn.uziy.backend.pricing

/**
 * Campaign pricing — the single source of truth for how a company's budget
 * is split between viewers and the platform.
 *
 * MUST stay byte-for-byte equivalent to `admin_panel/lib/pricing.ts`: the
 * wizard previews with the TS copy, the server recomputes with this one and
 * the server's numbers are what get saved and charged. Both suites carry the
 * same test vectors (V1–V10).
 *
 * Integer arithmetic only (whole tögrög, `Long`), no floating percentages:
 *
 *  - VIEWERS mode (company typed the viewer count N):
 *      costPerViewer   C = floor(B / N)
 *      rewardPerViewer R = floor(C * (100 - c) / 100)
 *  - REWARD mode (company typed the per-viewer reward R):
 *      costPerViewer   C = ceil(R * 100 / (100 - c))
 *      targetViewers   N = floor(B / C)
 *
 *  payable P = C * N (never more than B; the remainder B - P is not charged),
 *  commissionTotal = (C - R) * N, rewardsTotal = R * N.
 *
 * The multiplications by `(100 - c)` / `100` are done via a quotient +
 * remainder split so no intermediate product can overflow a Long; the
 * results are identical to the naive formulas above.
 */
enum class PricingMode { VIEWERS, REWARD }

/** Error codes, in the order they are checked (first match wins). */
enum class PricingError {
    BUDGET_INVALID,
    VIEWERS_INVALID,
    REWARD_INVALID,
    BUDGET_TOO_SMALL,
    REWARD_BELOW_MIN;

    /** Mongolian message shown to the company (same strings as the TS map). */
    fun message(minRewardPerViewer: Long): String = when (this) {
        BUDGET_INVALID   -> "Нийт төсвөө оруулна уу"
        VIEWERS_INVALID  -> "Үзэгчийн тоогоо оруулна уу"
        REWARD_INVALID   -> "Нэг үзэгчид олгох урамшууллаа оруулна уу"
        BUDGET_TOO_SMALL ->
            "Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү"
        REWARD_BELOW_MIN ->
            "Нэг үзэгчид олгох урамшуулал хамгийн багадаа $minRewardPerViewer ₮ байх ёстой"
    }
}

data class PricingResult(
    val mode: PricingMode,
    val budget: Long,
    val targetViewers: Long,
    val costPerViewer: Long,
    val rewardPerViewer: Long,
    val commissionPercent: Int,
    val payable: Long,
    val commissionTotal: Long,
    val rewardsTotal: Long,
    val unused: Long,
    val error: PricingError?,
) {
    val ok: Boolean get() = error == null
}

object CampaignPricing {

    const val MIN_COMMISSION_PERCENT = 1
    const val MAX_COMMISSION_PERCENT = 90

    /**
     * @param budget             B, whole ₮ the company is willing to spend.
     * @param commissionPercent  c, platform cut in percent (1..90).
     * @param minRewardPerViewer m, the admin-set floor for R (>= 1).
     * @param targetViewers      N — required (and only read) in VIEWERS mode.
     * @param rewardPerViewer    R — required (and only read) in REWARD mode.
     */
    fun compute(
        mode: PricingMode,
        budget: Long,
        commissionPercent: Int,
        minRewardPerViewer: Long,
        targetViewers: Long? = null,
        rewardPerViewer: Long? = null,
    ): PricingResult {
        require(commissionPercent in MIN_COMMISSION_PERCENT..MAX_COMMISSION_PERCENT) {
            "commissionPercent must be $MIN_COMMISSION_PERCENT..$MAX_COMMISSION_PERCENT, was $commissionPercent"
        }
        require(minRewardPerViewer >= 1) {
            "minRewardPerViewer must be >= 1, was $minRewardPerViewer"
        }

        val c = commissionPercent
        val keep = (100 - c).toLong() // viewer share, in percent (10..99)

        fun fail(
            error: PricingError,
            n: Long = 0, cost: Long = 0, reward: Long = 0,
        ): PricingResult = result(mode, budget, c, n, cost, reward, error)

        if (budget < 1) return fail(PricingError.BUDGET_INVALID)

        return when (mode) {
            PricingMode.VIEWERS -> {
                val n = targetViewers ?: 0
                if (n < 1) return fail(PricingError.VIEWERS_INVALID)
                val cost = budget / n
                // floor(cost * keep / 100) without overflow.
                val reward = (cost / 100) * keep + ((cost % 100) * keep) / 100
                val error = when {
                    cost < 1 -> PricingError.BUDGET_TOO_SMALL
                    reward < minRewardPerViewer -> PricingError.REWARD_BELOW_MIN
                    else -> null
                }
                result(mode, budget, c, n, cost, reward, error)
            }
            PricingMode.REWARD -> {
                val reward = rewardPerViewer ?: 0
                if (reward < 1) return fail(PricingError.REWARD_INVALID)
                // Only reachable for R in the quintillions: C itself doesn't
                // fit in a Long, so it certainly exceeds any Long budget.
                val cost = ceilCost(reward, keep)
                    ?: return fail(PricingError.BUDGET_TOO_SMALL, reward = reward)
                val n = budget / cost
                val error = when {
                    n < 1 -> PricingError.BUDGET_TOO_SMALL
                    reward < minRewardPerViewer -> PricingError.REWARD_BELOW_MIN
                    else -> null
                }
                result(mode, budget, c, n, cost, reward, error)
            }
        }
    }

    /** Convenience for VIEWERS mode. */
    fun forViewers(budget: Long, targetViewers: Long, commissionPercent: Int, minRewardPerViewer: Long) =
        compute(PricingMode.VIEWERS, budget, commissionPercent, minRewardPerViewer,
            targetViewers = targetViewers)

    /** Convenience for REWARD mode. */
    fun forReward(budget: Long, rewardPerViewer: Long, commissionPercent: Int, minRewardPerViewer: Long) =
        compute(PricingMode.REWARD, budget, commissionPercent, minRewardPerViewer,
            rewardPerViewer = rewardPerViewer)

    /**
     * ceil(reward * 100 / keep), computed as reward = q*keep + r so that
     * ceil = q*100 + ceil(r*100 / keep) — exact, and `null` instead of a
     * silently wrapped value if the true result doesn't fit in a Long.
     */
    private fun ceilCost(reward: Long, keep: Long): Long? {
        val q = reward / keep
        val r = reward % keep
        return try {
            Math.addExact(Math.multiplyExact(q, 100L), (r * 100 + keep - 1) / keep)
        } catch (_: ArithmeticException) {
            null
        }
    }

    private fun result(
        mode: PricingMode,
        budget: Long,
        commissionPercent: Int,
        n: Long,
        cost: Long,
        reward: Long,
        error: PricingError?,
    ): PricingResult {
        // Totals are only meaningful when at least one viewer is bought.
        val payable = if (n > 0 && cost > 0) cost * n else 0
        val rewardsTotal = if (payable > 0) reward * n else 0
        val commissionTotal = if (payable > 0) (cost - reward) * n else 0
        return PricingResult(
            mode = mode,
            budget = budget,
            targetViewers = n,
            costPerViewer = cost,
            rewardPerViewer = reward,
            commissionPercent = commissionPercent,
            payable = payable,
            commissionTotal = commissionTotal,
            rewardsTotal = rewardsTotal,
            unused = if (budget > 0) budget - payable else 0,
            error = error,
        )
    }
}
