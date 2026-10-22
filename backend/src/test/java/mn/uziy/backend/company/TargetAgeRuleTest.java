package mn.uziy.backend.company;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.uziy.backend.common.BadRequestException;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class TargetAgeRuleTest {

    @ParameterizedTest(name = "{0}–{1} is allowed")
    @CsvSource({
            "18, 23",   // exactly the minimum span
            "18, 45",
            "13, 99",   // the panel's widest
            "0, 100",   // the API's defaults when no ages are sent
            "0, 120",
    })
    void aWideEnoughRangeIsAllowed(int min, int max) {
        assertThatCode(() -> TargetAgeRule.check(min, max)).doesNotThrowAnyException();
    }

    /** Regression (2026-10-22 audit): 30–30 in one aimag could aim a survey at a handful of people. */
    @ParameterizedTest(name = "{0}–{1} is too narrow")
    @CsvSource({
            "30, 30",
            "30, 34",
            "40, 30",   // reversed
    })
    void aNarrowOrReversedRangeIsRefused(int min, int max) {
        assertThatThrownBy(() -> TargetAgeRule.check(min, max))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(TargetAgeRule.AGE_RANGE_TOO_NARROW);
    }

    @ParameterizedTest(name = "{0}–{1} is out of range")
    @CsvSource({
            "-1, 30",
            "18, 121",
    })
    void agesOutsideTheHumanRangeAreRefused(int min, int max) {
        assertThatThrownBy(() -> TargetAgeRule.check(min, max))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(TargetAgeRule.AGE_OUT_OF_RANGE);
    }
}
