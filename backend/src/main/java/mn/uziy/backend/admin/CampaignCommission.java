package mn.uziy.backend.admin;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.pricing.CampaignPricing;
import mn.uziy.backend.pricing.CommissionRange;
import mn.uziy.backend.pricing.PricingError;
import mn.uziy.backend.pricing.PricingResult;
import org.springframework.stereotype.Component;

/**
 * The admin sets each campaign's own commission when approving it (owner, 2026-10-30). The company has already
 * paid the cost per viewer C times the reach N; both stay. Only the split of C changes: the viewer's reward
 * R = floor(C × (100 − c) / 100), the platform keeps C − R. A percentage that would push R under the minimum
 * reward is refused, so a viewer never earns less than the platform promises.
 */
@Component
public class CampaignCommission {

    public static final String LEGACY_MESSAGE = "Хуучин үнийн загвартай судалгааны шимтгэлийг өөрчлөх боломжгүй";
    public static final String ONLY_ON_APPROVAL_MESSAGE = "Шимтгэлийг зөвхөн судалгааг зөвшөөрөхдөө тогтооно";

    /** The campaign's prices at {@code percent}; nothing is changed yet. */
    public PricingResult resplit(CampaignEntity campaign, Integer percent, long minRewardPerViewer) {
        int c = CommissionRange.check(percent);
        Integer viewers = campaign.getTargetViewers();
        if (viewers == null || viewers < 1 || campaign.getCommissionPercent() == null) {
            throw new ConflictException(LEGACY_MESSAGE);
        }
        long cost = (long) campaign.getCostPerView();
        // VIEWERS mode on exactly what was paid: cost = (C × N) / N = C, the reach stays N.
        PricingResult result = CampaignPricing.forViewers(cost * viewers, viewers, c, minRewardPerViewer);
        PricingError error = result.error();
        if (error != null) {
            throw new BadRequestException(error.message(minRewardPerViewer));
        }
        return result;
    }

    /** Writes the new split onto the campaign (the caller saves it inside its transaction). */
    public void apply(CampaignEntity campaign, PricingResult result) {
        campaign.setCommissionPercent(result.commissionPercent());
        campaign.setRewardPerUser((double) result.rewardPerViewer());
    }
}
