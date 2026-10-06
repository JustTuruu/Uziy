package mn.uziy.backend.payout;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Component;

/** Pattern: Chain of Responsibility link — the viewer must hold at least the requested amount. */
@Component
public class SufficientBalanceRule implements PayoutRule {

    @Override
    public void check(UserEntity user, CreatePayoutReq req) {
        if (user.getBalance() < req.amount()) {
            throw new BadRequestException("Insufficient balance");
        }
    }
}
