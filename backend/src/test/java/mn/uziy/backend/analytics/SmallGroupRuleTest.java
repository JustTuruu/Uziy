package mn.uziy.backend.analytics;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Stream;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

class SmallGroupRuleTest {

    private static final int MIN = 5;

    private static List<Slice> slices(long... counts) {
        return Arrays.stream(counts).mapToObj(n -> new Slice("s" + n, n)).toList();
    }

    static Stream<Arguments> cases() {
        return Stream.of(
                // description, slices, total the company sees, expected shown counts
                Arguments.of("every slice big enough", slices(7, 5), 12, List.of(7L, 5L)),
                Arguments.of("one small slice drags the other with it", slices(20, 2), 22, List.of()),
                Arguments.of("two small slices whose rest is big enough", slices(20, 3, 3), 26, List.of(20L)),
                Arguments.of("hidden rest topped up by the next smallest", slices(20, 10, 1), 31, List.of(20L)),
                Arguments.of("people outside every slice count as hidden", slices(5, 5), 12, List.of(5L)),
                Arguments.of("an outside rest big enough changes nothing", slices(10, 10), 25, List.of(10L, 10L)),
                Arguments.of("empty slices stay", slices(0, 12, 0), 12, List.of(0L, 12L, 0L)),
                Arguments.of("empty slices go when they would point at a small rest", slices(3, 0), 3, List.of()),
                Arguments.of("nothing at all", slices(), 0, List.of()),
                Arguments.of("a total below the slices' sum is not trusted", slices(6, 6), 0, List.of(6L, 6L)));
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("cases")
    void showsOnlySlicesThatNeitherPointAtNorGiveAwayAFewPeople(String description, List<Slice> slices, long total,
                                                                 List<Long> expected) {
        List<Slice> shown = SmallGroupRule.reportable(slices, total, MIN);

        assertThat(shown).extracting(Slice::count).containsExactlyElementsOf(expected);
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("cases")
    void whatIsLeftOutIsNobodyOrAtLeastTheMinimum(String description, List<Slice> slices, long total,
                                                  List<Long> expected) {
        long all = Math.max(total, slices.stream().mapToLong(Slice::count).sum());
        long hidden = all - SmallGroupRule.reportable(slices, total, MIN).stream().mapToLong(Slice::count).sum();

        assertThat(hidden == 0 || hidden >= MIN || all < MIN && hidden == all).isTrue();
    }
}
