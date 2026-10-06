package mn.uziy.backend.payout;

import java.util.List;

/** Viewer-facing payout use cases. */
public interface PayoutRequestService {
    /** Reserves {@link CreatePayoutReq#amount()} from the viewer's balance as a PENDING payout. */
    PayoutDto request(long userId, CreatePayoutReq req);

    List<PayoutDto> mine(long userId);
}
