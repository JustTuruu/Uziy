package mn.uziy.backend.payout;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.util.List;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;

class PayoutDecisionStrategyTest {

    private final UserRepository userRepository = mock(UserRepository.class);
    private final PayoutDecisionStrategies registry = new PayoutDecisionStrategies(
            List.of(new ApprovePayoutStrategy(), new RejectPayoutStrategy(userRepository)));

    private static UserEntity user(double balance) {
        UserEntity u = new UserEntity();
        u.setId(42L);
        u.setBalance(balance);
        return u;
    }

    private static PayoutEntity payout(double amount, boolean first) {
        PayoutEntity p = new PayoutEntity();
        p.setAmount(amount);
        p.setFirstPayout(first);
        return p;
    }

    @Test
    void registryPicksStrategyByDecision() {
        assertThat(registry.forDecision(PayoutStatus.APPROVED)).isInstanceOf(ApprovePayoutStrategy.class);
        assertThat(registry.forDecision(PayoutStatus.REJECTED)).isInstanceOf(RejectPayoutStrategy.class);
    }

    @Test
    void registryRefusesPending() {
        assertThatThrownBy(() -> registry.forDecision(PayoutStatus.PENDING))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(PayoutDecisionStrategies.NOT_A_DECISION);
    }

    @Test
    void approveFlipsVerifiedOnFirstPayoutOnly() {
        UserEntity first = user(100.0);
        new ApprovePayoutStrategy().apply(first, payout(500.0, true), "ignored");
        assertThat(first.isVerified()).isTrue();

        UserEntity repeat = user(100.0);
        PayoutEntity p = payout(500.0, false);
        new ApprovePayoutStrategy().apply(repeat, p, "ignored");
        assertThat(repeat.isVerified()).isFalse();
        assertThat(repeat.getBalance()).isEqualTo(100.0);
        assertThat(p.getRejectReason()).isNull();
    }

    @Test
    void rejectRefundsTheReservationAtomicallyAndStoresTheReason() {
        UserEntity u = user(200.0);
        PayoutEntity p = payout(500.0, true);

        new RejectPayoutStrategy(userRepository).apply(u, p, "name mismatch");

        verify(userRepository).addBalance(42L, 500.0);
        assertThat(u.getBalance()).as("the entity is not edited: a stale copy must never be written back")
                .isEqualTo(200.0);
        assertThat(u.isVerified()).isFalse();
        assertThat(p.getRejectReason()).isEqualTo("name mismatch");
    }

    @Test
    void approveNeverMovesMoney() {
        new ApprovePayoutStrategy().apply(user(100.0), payout(500.0, true), null);

        verify(userRepository, never()).addBalance(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyDouble());
    }
}
