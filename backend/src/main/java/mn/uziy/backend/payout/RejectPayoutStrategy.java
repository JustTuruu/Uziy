package mn.uziy.backend.payout;

import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Component;

/** Pattern: Strategy — REJECTED. Refunds the reserved balance and records the reason. */
@Component
public class RejectPayoutStrategy implements PayoutDecisionStrategy {

    @Override
    public PayoutStatus decision() {
        return PayoutStatus.REJECTED;
    }

    @Override
    public void apply(UserEntity user, PayoutEntity payout, @Nullable String reason) {
        user.setBalance(user.getBalance() + payout.getAmount()); // refund the reservation
        payout.setRejectReason(reason);
    }
}
