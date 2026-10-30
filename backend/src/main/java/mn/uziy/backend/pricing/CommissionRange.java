package mn.uziy.backend.pricing;

import mn.uziy.backend.common.BadRequestException;
import org.jspecify.annotations.Nullable;

/** The platform's cut an admin may set — a default in the settings or one campaign's own — always 1–90 %. */
public final class CommissionRange {

    public static final String MESSAGE = "Платформын шимтгэл "
            + CampaignPricing.MIN_COMMISSION_PERCENT + "–" + CampaignPricing.MAX_COMMISSION_PERCENT
            + "% хооронд байх ёстой";

    private CommissionRange() {
    }

    /** @throws BadRequestException with {@link #MESSAGE} for a missing or out-of-range value */
    public static int check(@Nullable Integer percent) {
        if (percent == null
                || percent < CampaignPricing.MIN_COMMISSION_PERCENT
                || percent > CampaignPricing.MAX_COMMISSION_PERCENT) {
            throw new BadRequestException(MESSAGE);
        }
        return percent;
    }
}
