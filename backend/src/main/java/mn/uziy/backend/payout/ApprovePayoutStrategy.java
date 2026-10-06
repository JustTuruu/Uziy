package mn.uziy.backend.payout;

import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Component;

/** Pattern: Strategy — APPROVED. Spec §4A: a first payout also flips users.is_verified. */
@Component
public class ApprovePayoutStrategy implements PayoutDecisionStrategy {

    @Override
    public PayoutStatus decision() {
        return PayoutStatus.APPROVED;
    }

    @Override
    public void apply(UserEntity user, PayoutEntity payout, @Nullable String reason) {
        if (payout.isFirstPayout()) {
            user.setVerified(true);
        }
        payout.setRejectReason(null);
    }
}
