package mn.uziy.backend.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashSet;
import org.junit.jupiter.api.Test;

class MongolianRegionsTest {

    @Test
    void thereAre21AimagsAnd9CapitalDistrictsWithoutDuplicates() {
        assertThat(MongolianRegions.AIMAGS).hasSize(21);
        assertThat(new HashSet<>(MongolianRegions.AIMAGS)).hasSize(21);
        assertThat(MongolianRegions.CAPITAL_DISTRICTS).hasSize(9);
        assertThat(MongolianRegions.AIMAGS).doesNotContain(MongolianRegions.CAPITAL);
    }

    @Test
    void theCapitalAndEveryAimagAreCitiesSpelledExactly() {
        assertThat(MongolianRegions.isCity("Улаанбаатар")).isTrue();
        assertThat(MongolianRegions.AIMAGS).allSatisfy(a -> assertThat(MongolianRegions.isCity(a)).isTrue());
        assertThat(MongolianRegions.isCity("Дархан")).isFalse();
        assertThat(MongolianRegions.isCity("улаанбаатар")).isFalse();
        assertThat(MongolianRegions.isCity("Бусад")).isFalse();
    }

    @Test
    void aCampaignMayTargetEverywhereOrOneCity() {
        assertThat(MongolianRegions.isTargetCity("ALL")).isTrue();
        assertThat(MongolianRegions.isTargetCity("Ховд")).isTrue();
        assertThat(MongolianRegions.isTargetCity("Эрдэнэт")).isFalse();
    }

    @Test
    void capitalDistrictsAreKnownByName() {
        assertThat(MongolianRegions.isCapitalDistrict("Хан-Уул")).isTrue();
        assertThat(MongolianRegions.isCapitalDistrict("Дархан")).isFalse();
    }
}
