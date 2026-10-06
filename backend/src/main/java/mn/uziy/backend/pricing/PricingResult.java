package mn.uziy.backend.pricing;

import org.jspecify.annotations.Nullable;

/** Outcome of {@link CampaignPricing#compute}; {@code error == null} means success. */
public record PricingResult(
        PricingMode mode,
        long budget,
        long targetViewers,
        long costPerViewer,
        long rewardPerViewer,
        int commissionPercent,
        long payable,
        long commissionTotal,
        long rewardsTotal,
        long unused,
        @Nullable PricingError error) {

    public boolean ok() {
        return error == null;
    }
}
