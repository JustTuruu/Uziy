package mn.uziy.backend.payout;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.util.List;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class PayoutRuleChainTest {

    private final UserEntity user = new UserEntity();
    private final CreatePayoutReq req = new CreatePayoutReq(500.0, "b", "1", "n", "id");

    @Test
    void sufficientBalanceRuleRejectsWhenBalanceIsLowerThanAmount() {
        user.setBalance(499.0);
        assertThatThrownBy(() -> new SufficientBalanceRule().check(user, req))
                .isInstanceOf(BadRequestException.class)
                .hasMessage("Insufficient balance");
    }

    @Test
    void sufficientBalanceRuleAcceptsExactBalance() {
        user.setBalance(500.0);
        assertThatCode(() -> new SufficientBalanceRule().check(user, req)).doesNotThrowAnyException();
    }

    @Test
    void chainStopsAtTheFirstFailingRuleAndKeepsOrder() {
        PayoutRule first = mock(PayoutRule.class);
        PayoutRule second = mock(PayoutRule.class);
        doThrow(new BadRequestException("first")).when(first).check(user, req);

        PayoutRuleChain chain = new PayoutRuleChain(List.of(first, second));

        assertThatThrownBy(() -> chain.validate(user, req)).hasMessage("first");
        verify(second, never()).check(any(), any());
    }

    @Test
    void chainRunsEveryRuleWhenAllPass() {
        PayoutRule first = mock(PayoutRule.class);
        PayoutRule second = mock(PayoutRule.class);

        new PayoutRuleChain(List.of(first, second)).validate(user, req);

        verify(first).check(user, req);
        verify(second).check(user, req);
    }
}
