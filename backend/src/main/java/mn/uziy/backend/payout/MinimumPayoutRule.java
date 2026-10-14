package mn.uziy.backend.payout;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.UserEntity;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/**
 * Pattern: Chain of Responsibility link — a payout is a whole number of tögrög of at least the minimum. The
 * viewer app enforces the same minimum in its form; this is the copy that cannot be bypassed, and the whole-number
 * rule keeps fractions of a tögrög (and rounding games) out of the books.
 */
@Component
@Order(1)
public class MinimumPayoutRule implements PayoutRule {

    public static final double MINIMUM_PAYOUT = 1000;
    static final String TOO_SMALL = "Хамгийн багадаа 1,000₮ татах боломжтой";
    static final String NOT_WHOLE = "Дүнг бүхэл төгрөгөөр оруулна уу";

    @Override
    public void check(UserEntity user, CreatePayoutReq req) {
        if (req.amount() != Math.floor(req.amount())) {
            throw new BadRequestException(NOT_WHOLE);
        }
        if (req.amount() < MINIMUM_PAYOUT) {
            throw new BadRequestException(TOO_SMALL);
        }
    }
}
