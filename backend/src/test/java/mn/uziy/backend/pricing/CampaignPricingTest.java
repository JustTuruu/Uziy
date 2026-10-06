package mn.uziy.backend.pricing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigInteger;
import java.util.Random;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

/**
 * Shared-contract test vectors V1–V10. The TypeScript twin
 * (company_panel/lib/pricing.test.ts) carries the same vectors — if one side
 * changes, the other must too.
 */
class CampaignPricingTest {

    private static final int C = 30;
    private static final long M = 100L;

    private static PricingResult viewers(long b, long n) {
        return viewers(b, n, C, M);
    }

    private static PricingResult viewers(long b, long n, int commission, long min) {
        return CampaignPricing.forViewers(b, n, commission, min);
    }

    private static PricingResult reward(long b, long r) {
        return reward(b, r, C, M);
    }

    private static PricingResult reward(long b, long r, int commission, long min) {
        return CampaignPricing.forReward(b, r, commission, min);
    }

    @Nested
    class ContractVectors {

        @Test
        void V1_VIEWERS_1_000_000_for_1_000_viewers_1000_per_viewer_700_reward() {
            PricingResult p = viewers(1_000_000, 1_000);
            assertThat(p.error()).isNull();
            assertThat(p.mode()).isEqualTo(PricingMode.VIEWERS);
            assertThat(p.budget()).isEqualTo(1_000_000);
            assertThat(p.targetViewers()).isEqualTo(1_000);
            assertThat(p.costPerViewer()).isEqualTo(1_000);
            assertThat(p.rewardPerViewer()).isEqualTo(700);
            assertThat(p.commissionPercent()).isEqualTo(30);
            assertThat(p.payable()).isEqualTo(1_000_000);
            assertThat(p.commissionTotal()).isEqualTo(300_000);
            assertThat(p.rewardsTotal()).isEqualTo(700_000);
            assertThat(p.unused()).isEqualTo(0);
        }

        @Test
        void V2_VIEWERS_1_000_000_for_1_428_viewers_leaves_400_unused() {
            PricingResult p = viewers(1_000_000, 1_428);
            assertThat(p.error()).isNull();
            assertThat(p.costPerViewer()).isEqualTo(700);
            assertThat(p.rewardPerViewer()).isEqualTo(490);
            assertThat(p.payable()).isEqualTo(999_600);
            assertThat(p.unused()).isEqualTo(400);
            assertThat(p.targetViewers()).isEqualTo(1_428);
        }

        @Test
        void V3_REWARD_700_per_viewer_from_1_000_000_reaches_1_000_viewers() {
            PricingResult p = reward(1_000_000, 700);
            assertThat(p.error()).isNull();
            assertThat(p.mode()).isEqualTo(PricingMode.REWARD);
            assertThat(p.costPerViewer()).isEqualTo(1_000);
            assertThat(p.targetViewers()).isEqualTo(1_000);
            assertThat(p.rewardPerViewer()).isEqualTo(700);
            assertThat(p.payable()).isEqualTo(1_000_000);
            assertThat(p.unused()).isEqualTo(0);
        }

        @Test
        void V4_REWARD_500_per_viewer_rounds_cost_up_to_715() {
            PricingResult p = reward(1_000_000, 500);
            assertThat(p.error()).isNull();
            assertThat(p.costPerViewer()).isEqualTo(715);
            assertThat(p.targetViewers()).isEqualTo(1_398);
            assertThat(p.payable()).isEqualTo(999_570);
            // (C - R) * N = 215 * 1,398. The shared contract text lists
            // 300,630 here, which is an arithmetic slip: it contradicts the
            // contract's own formula and P - R*N = 999,570 - 699,000.
            assertThat(p.commissionTotal()).isEqualTo(300_570);
            assertThat(p.rewardsTotal()).isEqualTo(699_000);
            assertThat(p.unused()).isEqualTo(430);
        }

        @Test
        void V5_VIEWERS_at_35_percent_commission() {
            PricingResult p = viewers(500_000, 1_000, 35, M);
            assertThat(p.error()).isNull();
            assertThat(p.costPerViewer()).isEqualTo(500);
            assertThat(p.rewardPerViewer()).isEqualTo(325);
            assertThat(p.commissionPercent()).isEqualTo(35);
            assertThat(p.commissionTotal()).isEqualTo(175_000);
        }

        @Test
        void V6_VIEWERS_budget_smaller_than_viewer_count_is_BUDGET_TOO_SMALL() {
            PricingResult p = viewers(500, 1_000);
            assertThat(p.error()).isEqualTo(PricingError.BUDGET_TOO_SMALL);
            assertThat(p.costPerViewer()).isEqualTo(0);
            assertThat(p.payable()).isEqualTo(0);
        }

        @Test
        void V7_VIEWERS_reward_under_the_admin_minimum_is_REWARD_BELOW_MIN() {
            PricingResult p = viewers(100_000, 1_000);
            assertThat(p.costPerViewer()).isEqualTo(100);
            assertThat(p.rewardPerViewer()).isEqualTo(70);
            assertThat(p.error()).isEqualTo(PricingError.REWARD_BELOW_MIN);
        }

        @Test
        void V8_REWARD_larger_than_the_budget_buys_zero_viewers() {
            PricingResult p = reward(500, 700);
            assertThat(p.costPerViewer()).isEqualTo(1_000);
            assertThat(p.targetViewers()).isEqualTo(0);
            assertThat(p.payable()).isEqualTo(0);
            assertThat(p.error()).isEqualTo(PricingError.BUDGET_TOO_SMALL);
        }

        @Test
        void V9_invalid_inputs() {
            assertThat(viewers(0, 1_000).error()).isEqualTo(PricingError.BUDGET_INVALID);
            assertThat(reward(0, 700).error()).isEqualTo(PricingError.BUDGET_INVALID);
            assertThat(viewers(-5, 1_000).error()).isEqualTo(PricingError.BUDGET_INVALID);
            assertThat(viewers(1_000_000, 0).error()).isEqualTo(PricingError.VIEWERS_INVALID);
            assertThat(viewers(1_000_000, -1).error()).isEqualTo(PricingError.VIEWERS_INVALID);
            assertThat(reward(1_000_000, 0).error()).isEqualTo(PricingError.REWARD_INVALID);
            assertThat(reward(1_000_000, -1).error()).isEqualTo(PricingError.REWARD_INVALID);
        }

        @Test
        void V10_large_budget_does_not_overflow() {
            PricingResult p = viewers(10_000_000_000L, 3);
            assertThat(p.error()).isNull();
            assertThat(p.costPerViewer()).isEqualTo(3_333_333_333L);
            assertThat(p.rewardPerViewer()).isEqualTo(2_333_333_333L);
            assertThat(p.payable()).isEqualTo(9_999_999_999L);
            assertThat(p.unused()).isEqualTo(1);
        }
    }

    @Nested
    class ErrorPrecedence {

        @Test
        void BUDGET_INVALID_wins_over_an_invalid_viewer_count() {
            assertThat(viewers(0, 0).error()).isEqualTo(PricingError.BUDGET_INVALID);
        }

        @Test
        void BUDGET_INVALID_wins_over_an_invalid_reward() {
            assertThat(reward(0, 0).error()).isEqualTo(PricingError.BUDGET_INVALID);
        }

        @Test
        void BUDGET_TOO_SMALL_wins_over_REWARD_BELOW_MIN() {
            // C = 0 -> R = 0 < m, but the budget error is reported first.
            assertThat(viewers(10, 100).error()).isEqualTo(PricingError.BUDGET_TOO_SMALL);
            // R = 50 < m and N = 0 — budget error first.
            assertThat(reward(10, 50).error()).isEqualTo(PricingError.BUDGET_TOO_SMALL);
        }

        @Test
        void REWARD_mode_below_the_minimum() {
            PricingResult p = reward(1_000_000, 50);
            assertThat(p.error()).isEqualTo(PricingError.REWARD_BELOW_MIN);
        }

        @Test
        void missing_driver_input_counts_as_invalid() {
            PricingResult v = CampaignPricing.compute(PricingMode.VIEWERS, 1_000, C, M, null, null);
            assertThat(v.error()).isEqualTo(PricingError.VIEWERS_INVALID);
            PricingResult r = CampaignPricing.compute(PricingMode.REWARD, 1_000, C, M, null, null);
            assertThat(r.error()).isEqualTo(PricingError.REWARD_INVALID);
        }

        @Test
        void reward_exactly_at_the_minimum_is_accepted() {
            // C = 143 -> R = floor(143 * 0.7) = 100 = m.
            PricingResult p = viewers(143_000, 1_000);
            assertThat(p.rewardPerViewer()).isEqualTo(100);
            assertThat(p.error()).isNull();
        }

        @Test
        void astronomical_reward_reports_BUDGET_TOO_SMALL_instead_of_overflowing() {
            PricingResult p = reward(Long.MAX_VALUE, Long.MAX_VALUE - 1);
            assertThat(p.error()).isEqualTo(PricingError.BUDGET_TOO_SMALL);
            assertThat(p.payable()).isEqualTo(0);
        }
    }

    @Nested
    class Messages {

        @Test
        void Mongolian_messages_match_the_shared_contract() {
            assertThat(PricingError.BUDGET_INVALID.message(100)).isEqualTo("Нийт төсвөө оруулна уу");
            assertThat(PricingError.VIEWERS_INVALID.message(100)).isEqualTo("Үзэгчийн тоогоо оруулна уу");
            assertThat(PricingError.REWARD_INVALID.message(100))
                    .isEqualTo("Нэг үзэгчид олгох урамшууллаа оруулна уу");
            assertThat(PricingError.BUDGET_TOO_SMALL.message(100))
                    .isEqualTo("Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү");
            assertThat(PricingError.REWARD_BELOW_MIN.message(150))
                    .isEqualTo("Нэг үзэгчид олгох урамшуулал хамгийн багадаа 150 ₮ байх ёстой");
        }
    }

    @Nested
    class Preconditions {

        @Test
        void commission_outside_1_90_is_a_programming_error() {
            assertThatThrownBy(() -> viewers(1_000, 1, 0, M)).isInstanceOf(IllegalArgumentException.class);
            assertThatThrownBy(() -> viewers(1_000, 1, 91, M)).isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void minimum_reward_below_1_is_a_programming_error() {
            assertThatThrownBy(() -> viewers(1_000, 1, C, 0)).isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void commission_bounds_1_and_90_are_accepted() {
            assertThat(viewers(100_000, 1_000, 1, 1).rewardPerViewer()).isEqualTo(99);
            assertThat(viewers(100_000, 1_000, 90, 1).rewardPerViewer()).isEqualTo(10);
        }
    }

    @Nested
    class Invariants {

        /** Naive formulas from the contract, in BigInteger, as an oracle: {cost, reward}. */
        private long[] oracleViewers(long b, long n, int commission) {
            BigInteger cost = BigInteger.valueOf(b).divide(BigInteger.valueOf(n));
            BigInteger r = cost.multiply(BigInteger.valueOf(100L - commission)).divide(BigInteger.valueOf(100));
            return new long[] {cost.longValueExact(), r.longValueExact()};
        }

        /** {cost, viewers}. */
        private long[] oracleReward(long b, long r, int commission) {
            BigInteger keep = BigInteger.valueOf(100L - commission);
            BigInteger cost = BigInteger.valueOf(r).multiply(BigInteger.valueOf(100))
                    .add(keep).subtract(BigInteger.ONE).divide(keep);
            BigInteger n = BigInteger.valueOf(b).divide(cost);
            return new long[] {cost.longValueExact(), n.longValueExact()};
        }

        private void assertInvariants(PricingResult p) {
            if (p.error() != null) {
                return;
            }
            assertThat(p.rewardPerViewer()).as("R >= 1: %s", p).isGreaterThanOrEqualTo(1);
            assertThat(p.rewardPerViewer()).as("R < C: %s", p).isLessThan(p.costPerViewer());
            assertThat(p.payable()).as("P <= B: %s", p).isLessThanOrEqualTo(p.budget());
            assertThat(p.targetViewers()).as("N >= 1: %s", p).isGreaterThanOrEqualTo(1);
            assertThat(p.payable()).isEqualTo(p.costPerViewer() * p.targetViewers());
            assertThat(p.commissionTotal() + p.rewardsTotal()).isEqualTo(p.payable());
            assertThat(p.unused()).isEqualTo(p.budget() - p.payable());
        }

        @Test
        void whenever_error_is_null_1_le_R_lt_C_and_P_le_B_random_sweep() {
            Random rnd = new Random(20260928);
            for (int i = 0; i < 20_000; i++) {
                int commission = rnd.nextInt(1, 91);
                long min = rnd.nextLong(1, 500);
                long b;
                switch (rnd.nextInt(3)) {
                    case 0 -> b = rnd.nextLong(1, 10_000);
                    case 1 -> b = rnd.nextLong(1, 100_000_000);
                    default -> b = rnd.nextLong(1, 1_000_000_000_000_000L);
                }
                long n = rnd.nextLong(1, 2_000_000);
                long r = rnd.nextLong(1, 100_000);

                PricingResult pv = viewers(b, n, commission, min);
                assertInvariants(pv);
                long[] ov = oracleViewers(b, n, commission);
                assertThat(pv.costPerViewer()).as("VIEWERS C b=%d n=%d c=%d", b, n, commission).isEqualTo(ov[0]);
                assertThat(pv.rewardPerViewer()).as("VIEWERS R b=%d n=%d c=%d", b, n, commission).isEqualTo(ov[1]);

                PricingResult pr = reward(b, r, commission, min);
                assertInvariants(pr);
                long[] or = oracleReward(b, r, commission);
                assertThat(pr.costPerViewer()).as("REWARD C b=%d r=%d c=%d", b, r, commission).isEqualTo(or[0]);
                assertThat(pr.targetViewers()).as("REWARD N b=%d r=%d c=%d", b, r, commission).isEqualTo(or[1]);
            }
        }

        @Test
        void round_trip_the_reward_computed_in_VIEWERS_mode_reaches_at_least_as_many_viewers_in_REWARD_mode() {
            Random rnd = new Random(7);
            for (int i = 0; i < 5_000; i++) {
                int commission = rnd.nextInt(1, 91);
                long b = rnd.nextLong(1_000, 100_000_000);
                long n = rnd.nextLong(1, 10_000);
                PricingResult pv = viewers(b, n, commission, 1);
                if (pv.error() != null) {
                    continue;
                }
                PricingResult pr = reward(b, pv.rewardPerViewer(), commission, 1);
                assertThat(pr.error()).isNull();
                assertThat(pr.costPerViewer()).isLessThanOrEqualTo(pv.costPerViewer());
                assertThat(pr.targetViewers()).isGreaterThanOrEqualTo(n);
            }
        }
    }
}
