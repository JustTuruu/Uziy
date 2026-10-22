package mn.uziy.backend.payout;

import java.util.List;
import mn.uziy.backend.domain.PayoutStatus;
import org.jspecify.annotations.Nullable;

/**
 * Admin-facing payout use cases. Every read is written to the data access log ({@code adminId}); decided requests
 * come back with a masked account number.
 */
public interface PayoutReviewService {
    List<PayoutDto> pending(long adminId);

    /**
     * Decided payouts (approved + rejected), newest-first, so old requests
     * stay visible after a refresh.
     */
    List<PayoutDto> history(long adminId);

    /**
     * Approve or reject. Spec §4A: on APPROVED (first payout only) also
     * flip users.is_verified = TRUE. On REJECTED refund the reserved balance.
     */
    PayoutDto decide(long payoutId, PayoutStatus decision, @Nullable String reason, long adminId);
}
