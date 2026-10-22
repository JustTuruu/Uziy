package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import mn.uziy.backend.common.BadRequestException;
import org.junit.jupiter.api.Test;

class ViewerAgeRuleTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 10, 22);

    @Test
    void thirteenOnTheDayAndOlderPass() {
        assertThatCode(() -> ViewerAgeRule.check(LocalDate.of(2013, 10, 22), TODAY)).doesNotThrowAnyException();
        assertThatCode(() -> ViewerAgeRule.check(LocalDate.of(1980, 3, 1), TODAY)).doesNotThrowAnyException();
    }

    @Test
    void oneDayShortOfThirteenIsTooYoung() {
        assertThatThrownBy(() -> ViewerAgeRule.check(LocalDate.of(2013, 10, 23), TODAY))
                .isInstanceOf(BadRequestException.class).hasMessage(ViewerAgeRule.TOO_YOUNG);
    }

    @Test
    void aFutureOrImpossiblyOldDateIsNotABirthDate() {
        assertThatThrownBy(() -> ViewerAgeRule.check(LocalDate.of(2027, 1, 1), TODAY))
                .hasMessage(ViewerAgeRule.NOT_A_BIRTH_DATE);
        assertThatThrownBy(() -> ViewerAgeRule.check(LocalDate.of(1900, 1, 1), TODAY))
                .hasMessage(ViewerAgeRule.NOT_A_BIRTH_DATE);
    }
}
