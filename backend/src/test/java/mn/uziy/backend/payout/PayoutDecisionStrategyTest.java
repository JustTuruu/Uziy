package mn.uziy.backend.payout;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class PayoutDecisionStrategyTest {

    private final PayoutDecisionStrategies registry =
            new PayoutDecisionStrategies(List.of(new ApprovePayoutStrategy(), new RejectPayoutStrategy()));

    private static UserEntity user(double balance) {
        UserEntity u = new UserEntity();
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
                .hasMessage("Cannot set PENDING");
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
    void rejectRefundsBalanceAndStoresReason() {
        UserEntity u = user(200.0);
        PayoutEntity p = payout(500.0, true);
        new RejectPayoutStrategy().apply(u, p, "name mismatch");
        assertThat(u.getBalance()).isEqualTo(700.0);
        assertThat(u.isVerified()).isFalse();
        assertThat(p.getRejectReason()).isEqualTo("name mismatch");
    }
}
