package mn.uziy.backend.payout;

import java.util.List;
import mn.uziy.backend.domain.PayoutStatus;
import org.jspecify.annotations.Nullable;

/** Admin-facing payout use cases. */
public interface PayoutReviewService {
    List<PayoutDto> pending();

    /**
     * Decided payouts (approved + rejected), newest-first, so old requests
     * stay visible after a refresh.
     */
    List<PayoutDto> history();

    /**
     * Approve or reject. Spec §4A: on APPROVED (first payout only) also
     * flip users.is_verified = TRUE. On REJECTED refund the reserved balance.
     */
    PayoutDto decide(long payoutId, PayoutStatus decision, @Nullable String reason, long adminId);
}
