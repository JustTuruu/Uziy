package mn.uziy.backend.analytics;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import org.junit.jupiter.api.Test;

class AgeBandsTest {

    @Test
    void alwaysReturnsAllFiveBandsInOrderEvenWhenEmpty() {
        assertThat(AgeBands.group(Map.of())).containsExactly(
                new Slice("13–17", 0), new Slice("18–24", 0), new Slice("25–34", 0),
                new Slice("35–44", 0), new Slice("45+", 0));
    }

    @Test
    void edgesBelongToTheBandTheyOpenOrClose() {
        Map<Integer, Long> ages = Map.of(13, 1L, 17, 2L, 18, 4L, 24, 8L, 25, 16L, 34, 32L, 35, 64L, 44, 128L, 45, 256L);

        assertThat(AgeBands.group(ages)).containsExactly(
                new Slice("13–17", 3), new Slice("18–24", 12), new Slice("25–34", 48),
                new Slice("35–44", 192), new Slice("45+", 256));
    }

    @Test
    void anyAgeAbove45LandsInTheLastBand() {
        assertThat(AgeBands.group(Map.of(45, 1L, 63, 2L, 99, 3L)).get(4)).isEqualTo(new Slice("45+", 6));
    }

    @Test
    void labelOfNamesTheBandOfAnAge() {
        assertThat(AgeBands.labelOf(15)).isEqualTo("13–17");
        assertThat(AgeBands.labelOf(18)).isEqualTo("18–24");
        assertThat(AgeBands.labelOf(30)).isEqualTo("25–34");
        assertThat(AgeBands.labelOf(44)).isEqualTo("35–44");
        assertThat(AgeBands.labelOf(70)).isEqualTo("45+");
    }

    @Test
    void sumsSeveralAgesOfTheSameBand() {
        assertThat(AgeBands.group(Map.of(19, 5L, 20, 7L, 23, 1L)).get(1)).isEqualTo(new Slice("18–24", 13));
    }
}
