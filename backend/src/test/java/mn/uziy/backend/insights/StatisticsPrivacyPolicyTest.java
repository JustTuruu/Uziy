package mn.uziy.backend.insights;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class StatisticsPrivacyPolicyTest {

    @Test
    void theOwnerChoseFiftyAsTheSmallestGroup() {
        assertThat(StatisticsPrivacyPolicy.MIN_GROUP_SIZE).isEqualTo(50);
        assertThat(StatisticsPrivacyPolicy.reportable(49)).isFalse();
        assertThat(StatisticsPrivacyPolicy.reportable(50)).isTrue();
    }

    @Test
    void onlyAdultsCount() {
        assertThat(StatisticsPrivacyPolicy.MIN_AGE).isEqualTo(18);
        assertThat(InsightsRepository.CONSENTING).contains("INTERVAL '18 years'").contains("'GRANTED'");
    }

    @Test
    void aGroupWithASmallRemainderIsHiddenSoSubtractionRevealsNobody() {
        assertThat(StatisticsPrivacyPolicy.reportable(60, 60)).isTrue();   // the whole: nothing left over
        assertThat(StatisticsPrivacyPolicy.reportable(55, 60)).isFalse();  // the other 5 would show by subtraction
        assertThat(StatisticsPrivacyPolicy.reportable(50, 100)).isTrue();
        assertThat(StatisticsPrivacyPolicy.reportable(40, 100)).isFalse();
    }

    @Test
    void countsRoundDownToTensAndSharesAreWholePercent() {
        assertThat(StatisticsPrivacyPolicy.roundedCount(57)).isEqualTo(50);
        assertThat(StatisticsPrivacyPolicy.roundedCount(130)).isEqualTo(130);
        assertThat(StatisticsPrivacyPolicy.percent(1, 3)).isEqualTo(33);
        assertThat(StatisticsPrivacyPolicy.percent(2, 3)).isEqualTo(67);
        assertThat(StatisticsPrivacyPolicy.percent(5, 0)).isZero();
    }
}
