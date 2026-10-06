package mn.uziy.backend.payout;

/** Cash-out use cases: the viewer asks, the super admin decides. */
public interface PayoutService extends PayoutRequestService, PayoutReviewService {
}
