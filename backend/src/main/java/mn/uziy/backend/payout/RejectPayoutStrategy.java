package mn.uziy.backend.payout;

import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Component;

/** Pattern: Strategy — REJECTED. Refunds the reserved balance and records the reason. */
@Component
public class RejectPayoutStrategy implements PayoutDecisionStrategy {

    private final UserRepository users;

    public RejectPayoutStrategy(UserRepository users) {
        this.users = users;
    }

    @Override
    public PayoutStatus decision() {
        return PayoutStatus.REJECTED;
    }

    @Override
    public void apply(UserEntity user, PayoutEntity payout, @Nullable String reason) {
        // Atomic, so a refund can never overwrite a reward credited at the same moment.
        users.addBalance(user.getId(), payout.getAmount());
        payout.setRejectReason(reason);
    }
}
