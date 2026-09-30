package mn.uziy.backend.pricing

import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.math.BigInteger
import kotlin.random.Random
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Shared-contract test vectors V1–V10. The TypeScript twin
 * (admin_panel/lib/pricing.test.ts) carries the same vectors — if one side
 * changes, the other must too.
 */
class CampaignPricingTest {

    private val c = 30
    private val m = 100L

    private fun viewers(b: Long, n: Long, commission: Int = c, min: Long = m) =
        CampaignPricing.forViewers(b, n, commission, min)

    private fun reward(b: Long, r: Long, commission: Int = c, min: Long = m) =
        CampaignPricing.forReward(b, r, commission, min)

    @Nested
    inner class ContractVectors {

        @Test
        fun `V1 VIEWERS 1,000,000 for 1,000 viewers - 1000 per viewer, 700 reward`() {
            val p = viewers(1_000_000, 1_000)
            assertNull(p.error)
            assertEquals(PricingMode.VIEWERS, p.mode)
            assertEquals(1_000_000, p.budget)
            assertEquals(1_000, p.targetViewers)
            assertEquals(1_000, p.costPerViewer)
            assertEquals(700, p.rewardPerViewer)
            assertEquals(30, p.commissionPercent)
            assertEquals(1_000_000, p.payable)
            assertEquals(300_000, p.commissionTotal)
            assertEquals(700_000, p.rewardsTotal)
            assertEquals(0, p.unused)
        }

        @Test
        fun `V2 VIEWERS 1,000,000 for 1,428 viewers leaves 400 unused`() {
            val p = viewers(1_000_000, 1_428)
            assertNull(p.error)
            assertEquals(700, p.costPerViewer)
            assertEquals(490, p.rewardPerViewer)
            assertEquals(999_600, p.payable)
            assertEquals(400, p.unused)
            assertEquals(1_428, p.targetViewers)
        }

        @Test
        fun `V3 REWARD 700 per viewer from 1,000,000 reaches 1,000 viewers`() {
            val p = reward(1_000_000, 700)
            assertNull(p.error)
            assertEquals(PricingMode.REWARD, p.mode)
            assertEquals(1_000, p.costPerViewer)
            assertEquals(1_000, p.targetViewers)
            assertEquals(700, p.rewardPerViewer)
            assertEquals(1_000_000, p.payable)
            assertEquals(0, p.unused)
        }

        @Test
        fun `V4 REWARD 500 per viewer rounds cost up to 715`() {
            val p = reward(1_000_000, 500)
            assertNull(p.error)
            assertEquals(715, p.costPerViewer)
            assertEquals(1_398, p.targetViewers)
            assertEquals(999_570, p.payable)
            // (C - R) * N = 215 * 1,398. The shared contract text lists
            // 300,630 here, which is an arithmetic slip: it contradicts the
            // contract's own formula and P - R*N = 999,570 - 699,000.
            assertEquals(300_570, p.commissionTotal)
            assertEquals(699_000, p.rewardsTotal)
            assertEquals(430, p.unused)
        }

        @Test
        fun `V5 VIEWERS at 35 percent commission`() {
            val p = viewers(500_000, 1_000, commission = 35)
            assertNull(p.error)
            assertEquals(500, p.costPerViewer)
            assertEquals(325, p.rewardPerViewer)
            assertEquals(35, p.commissionPercent)
            assertEquals(175_000, p.commissionTotal)
        }

        @Test
        fun `V6 VIEWERS budget smaller than viewer count is BUDGET_TOO_SMALL`() {
            val p = viewers(500, 1_000)
            assertEquals(PricingError.BUDGET_TOO_SMALL, p.error)
            assertEquals(0, p.costPerViewer)
            assertEquals(0, p.payable)
        }

        @Test
        fun `V7 VIEWERS reward under the admin minimum is REWARD_BELOW_MIN`() {
            val p = viewers(100_000, 1_000)
            assertEquals(100, p.costPerViewer)
            assertEquals(70, p.rewardPerViewer)
            assertEquals(PricingError.REWARD_BELOW_MIN, p.error)
        }

        @Test
        fun `V8 REWARD larger than the budget buys zero viewers`() {
            val p = reward(500, 700)
            assertEquals(1_000, p.costPerViewer)
            assertEquals(0, p.targetViewers)
            assertEquals(0, p.payable)
            assertEquals(PricingError.BUDGET_TOO_SMALL, p.error)
        }

        @Test
        fun `V9 invalid inputs`() {
            assertEquals(PricingError.BUDGET_INVALID, viewers(0, 1_000).error)
            assertEquals(PricingError.BUDGET_INVALID, reward(0, 700).error)
            assertEquals(PricingError.BUDGET_INVALID, viewers(-5, 1_000).error)
            assertEquals(PricingError.VIEWERS_INVALID, viewers(1_000_000, 0).error)
            assertEquals(PricingError.VIEWERS_INVALID, viewers(1_000_000, -1).error)
            assertEquals(PricingError.REWARD_INVALID, reward(1_000_000, 0).error)
            assertEquals(PricingError.REWARD_INVALID, reward(1_000_000, -1).error)
        }

        @Test
        fun `V10 large budget does not overflow`() {
            val p = viewers(10_000_000_000, 3)
            assertNull(p.error)
            assertEquals(3_333_333_333, p.costPerViewer)
            assertEquals(2_333_333_333, p.rewardPerViewer)
            assertEquals(9_999_999_999, p.payable)
            assertEquals(1, p.unused)
        }
    }

    @Nested
    inner class ErrorPrecedence {

        @Test
        fun `BUDGET_INVALID wins over an invalid viewer count`() {
            assertEquals(PricingError.BUDGET_INVALID, viewers(0, 0).error)
        }

        @Test
        fun `BUDGET_INVALID wins over an invalid reward`() {
            assertEquals(PricingError.BUDGET_INVALID, reward(0, 0).error)
        }

        @Test
        fun `BUDGET_TOO_SMALL wins over REWARD_BELOW_MIN`() {
            // C = 0 → R = 0 < m, but the budget error is reported first.
            assertEquals(PricingError.BUDGET_TOO_SMALL, viewers(10, 100).error)
            // R = 50 < m and N = 0 — budget error first.
            assertEquals(PricingError.BUDGET_TOO_SMALL, reward(10, 50).error)
        }

        @Test
        fun `REWARD mode below the minimum`() {
            val p = reward(1_000_000, 50)
            assertEquals(PricingError.REWARD_BELOW_MIN, p.error)
        }

        @Test
        fun `missing driver input counts as invalid`() {
            val v = CampaignPricing.compute(PricingMode.VIEWERS, 1_000, c, m)
            assertEquals(PricingError.VIEWERS_INVALID, v.error)
            val r = CampaignPricing.compute(PricingMode.REWARD, 1_000, c, m)
            assertEquals(PricingError.REWARD_INVALID, r.error)
        }

        @Test
        fun `reward exactly at the minimum is accepted`() {
            // C = 143 → R = floor(143 * 0.7) = 100 = m.
            val p = viewers(143_000, 1_000)
            assertEquals(100, p.rewardPerViewer)
            assertNull(p.error)
        }

        @Test
        fun `astronomical reward reports BUDGET_TOO_SMALL instead of overflowing`() {
            val p = reward(Long.MAX_VALUE, Long.MAX_VALUE - 1)
            assertEquals(PricingError.BUDGET_TOO_SMALL, p.error)
            assertEquals(0, p.payable)
        }
    }

    @Nested
    inner class Messages {

        @Test
        fun `Mongolian messages match the shared contract`() {
            assertEquals("Нийт төсвөө оруулна уу", PricingError.BUDGET_INVALID.message(100))
            assertEquals("Үзэгчийн тоогоо оруулна уу", PricingError.VIEWERS_INVALID.message(100))
            assertEquals("Нэг үзэгчид олгох урамшууллаа оруулна уу",
                PricingError.REWARD_INVALID.message(100))
            assertEquals(
                "Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү",
                PricingError.BUDGET_TOO_SMALL.message(100),
            )
            assertEquals(
                "Нэг үзэгчид олгох урамшуулал хамгийн багадаа 150 ₮ байх ёстой",
                PricingError.REWARD_BELOW_MIN.message(150),
            )
        }
    }

    @Nested
    inner class Preconditions {

        @Test
        fun `commission outside 1-90 is a programming error`() {
            assertFailsWith<IllegalArgumentException> { viewers(1_000, 1, commission = 0) }
            assertFailsWith<IllegalArgumentException> { viewers(1_000, 1, commission = 91) }
        }

        @Test
        fun `minimum reward below 1 is a programming error`() {
            assertFailsWith<IllegalArgumentException> { viewers(1_000, 1, min = 0) }
        }

        @Test
        fun `commission bounds 1 and 90 are accepted`() {
            assertEquals(99, viewers(100_000, 1_000, commission = 1, min = 1).rewardPerViewer)
            assertEquals(10, viewers(100_000, 1_000, commission = 90, min = 1).rewardPerViewer)
        }
    }

    @Nested
    inner class Invariants {

        /** Naive formulas from the contract, in BigInteger, as an oracle. */
        private fun oracleViewers(b: Long, n: Long, commission: Int): Pair<Long, Long> {
            val cost = BigInteger.valueOf(b) / BigInteger.valueOf(n)
            val r = cost * BigInteger.valueOf(100L - commission) / BigInteger.valueOf(100)
            return cost.toLong() to r.toLong()
        }

        private fun oracleReward(b: Long, r: Long, commission: Int): Pair<Long, Long> {
            val keep = BigInteger.valueOf(100L - commission)
            val cost = (BigInteger.valueOf(r) * BigInteger.valueOf(100) + keep - BigInteger.ONE) / keep
            val n = BigInteger.valueOf(b) / cost
            return cost.toLong() to n.toLong()
        }

        private fun assertInvariants(p: PricingResult) {
            if (p.error != null) return
            assertTrue(p.rewardPerViewer >= 1, "R >= 1: $p")
            assertTrue(p.rewardPerViewer < p.costPerViewer, "R < C: $p")
            assertTrue(p.payable <= p.budget, "P <= B: $p")
            assertTrue(p.targetViewers >= 1, "N >= 1: $p")
            assertEquals(p.costPerViewer * p.targetViewers, p.payable)
            assertEquals(p.payable, p.commissionTotal + p.rewardsTotal)
            assertEquals(p.budget - p.payable, p.unused)
        }

        @Test
        fun `whenever error is null, 1 le R lt C and P le B (random sweep)`() {
            val rnd = Random(20260928)
            repeat(20_000) {
                val commission = rnd.nextInt(1, 91)
                val min = rnd.nextLong(1, 500)
                val b = when (rnd.nextInt(3)) {
                    0 -> rnd.nextLong(1, 10_000)
                    1 -> rnd.nextLong(1, 100_000_000)
                    else -> rnd.nextLong(1, 1_000_000_000_000_000)
                }
                val n = rnd.nextLong(1, 2_000_000)
                val r = rnd.nextLong(1, 100_000)

                val pv = viewers(b, n, commission, min)
                assertInvariants(pv)
                val (oc, or) = oracleViewers(b, n, commission)
                assertEquals(oc, pv.costPerViewer, "VIEWERS C b=$b n=$n c=$commission")
                assertEquals(or, pv.rewardPerViewer, "VIEWERS R b=$b n=$n c=$commission")

                val pr = reward(b, r, commission, min)
                assertInvariants(pr)
                val (rc, rn) = oracleReward(b, r, commission)
                assertEquals(rc, pr.costPerViewer, "REWARD C b=$b r=$r c=$commission")
                assertEquals(rn, pr.targetViewers, "REWARD N b=$b r=$r c=$commission")
            }
        }

        @Test
        fun `round trip - the reward computed in VIEWERS mode reaches at least as many viewers in REWARD mode`() {
            val rnd = Random(7)
            repeat(5_000) {
                val commission = rnd.nextInt(1, 91)
                val b = rnd.nextLong(1_000, 100_000_000)
                val n = rnd.nextLong(1, 10_000)
                val pv = viewers(b, n, commission, 1)
                if (pv.error != null) return@repeat
                val pr = reward(b, pv.rewardPerViewer, commission, 1)
                assertNull(pr.error)
                assertTrue(pr.costPerViewer <= pv.costPerViewer)
                assertTrue(pr.targetViewers >= n)
            }
        }
    }
}
