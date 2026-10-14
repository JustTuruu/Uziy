package mn.uziy.backend.payout;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class MinimumPayoutRuleTest {

    private final MinimumPayoutRule rule = new MinimumPayoutRule();
    private final UserEntity user = new UserEntity();

    private static CreatePayoutReq req(double amount) {
        return new CreatePayoutReq(amount, "Khan Bank", "1", "A");
    }

    @Test
    void theMinimumItselfAndAnythingAboveItInWholeTogrogPass() {
        assertThatCode(() -> rule.check(user, req(1000))).doesNotThrowAnyException();
        assertThatCode(() -> rule.check(user, req(250_000))).doesNotThrowAnyException();
    }

    @Test
    void anythingBelowTheMinimumIsRefused() {
        assertThatThrownBy(() -> rule.check(user, req(999)))
                .isInstanceOf(BadRequestException.class).hasMessage(MinimumPayoutRule.TOO_SMALL);
        assertThatThrownBy(() -> rule.check(user, req(0.0001)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void fractionsOfATogrogAreRefused() {
        assertThatThrownBy(() -> rule.check(user, req(1000.5)))
                .isInstanceOf(BadRequestException.class).hasMessage(MinimumPayoutRule.NOT_WHOLE);
    }
}
