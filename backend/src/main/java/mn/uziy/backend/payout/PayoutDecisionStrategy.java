package mn.uziy.backend.payout;

import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import org.jspecify.annotations.Nullable;

/**
 * Pattern: Strategy — what an admin decision does to the viewer and the payout row.
 * Implementations mutate the entities only; the service persists them.
 */
public interface PayoutDecisionStrategy {
    /** The decision this strategy handles. */
    PayoutStatus decision();

    void apply(UserEntity user, PayoutEntity payout, @Nullable String reason);
}
