package mn.uziy.backend.payout;

import mn.uziy.backend.domain.UserEntity;

/**
 * Pattern: Chain of Responsibility — one link of the payout-request validation chain.
 * Implementations throw a {@code DomainException} when the request must be refused.
 */
public interface PayoutRule {
    void check(UserEntity user, CreatePayoutReq req);
}
