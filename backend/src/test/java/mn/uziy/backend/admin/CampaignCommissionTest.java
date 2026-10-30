package mn.uziy.backend.admin;

import static mn.uziy.backend.admin.AdminTestData.campaign;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.pricing.CommissionRange;
import mn.uziy.backend.pricing.PricingResult;
import org.junit.jupiter.api.Test;

class CampaignCommissionTest {

    private static final long MIN_REWARD = 100;

    private final CampaignCommission commission = new CampaignCommission();

    /** Paid 1,000 ₮ per viewer for 1,000 viewers at 30 %: 700 ₮ each to the viewer. */
    private static CampaignEntity paid() {
        CampaignEntity c = campaign(1, CampaignStatus.PENDING);
        c.setCostPerView(1_000.0);
        c.setTargetViewers(1_000);
        c.setCommissionPercent(30);
        c.setRewardPerUser(700.0);
        return c;
    }

    @Test
    void aHigherCommissionLowersTheRewardButKeepsWhatWasPaidAndTheReach() {
        PricingResult split = commission.resplit(paid(), 40, MIN_REWARD);

        assertThat(split.rewardPerViewer()).isEqualTo(600);
        assertThat(split.costPerViewer()).isEqualTo(1_000);
        assertThat(split.targetViewers()).isEqualTo(1_000);
        assertThat(split.payable()).isEqualTo(1_000_000);
        assertThat(split.commissionTotal()).isEqualTo(400_000);
    }

    @Test
    void applyWritesTheNewSplitOnTheCampaign() {
        CampaignEntity c = paid();
        commission.apply(c, commission.resplit(c, 20, MIN_REWARD));

        assertThat(c.getCommissionPercent()).isEqualTo(20);
        assertThat(c.getRewardPerUser()).isEqualTo(800.0);
        assertThat(c.getCostPerView()).isEqualTo(1_000.0);
        assertThat(c.getTotalBudget()).isEqualTo(1_000_000.0);
    }

    @Test
    void aCommissionThatPushesTheRewardUnderTheMinimumIsRefused() {
        assertThatThrownBy(() -> commission.resplit(paid(), 50, 600))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("600 ₮");
    }

    @Test
    void theCommissionMustBe1To90() {
        assertThatThrownBy(() -> commission.resplit(paid(), 0, MIN_REWARD))
                .isInstanceOf(BadRequestException.class).hasMessage(CommissionRange.MESSAGE);
        assertThatThrownBy(() -> commission.resplit(paid(), 91, MIN_REWARD))
                .isInstanceOf(BadRequestException.class).hasMessage(CommissionRange.MESSAGE);
    }

    @Test
    void aCampaignOfTheOldPriceModelCannotBeReSplit() {
        CampaignEntity legacy = paid();
        legacy.setCommissionPercent(null);
        assertThatThrownBy(() -> commission.resplit(legacy, 30, MIN_REWARD))
                .isInstanceOf(ConflictException.class).hasMessage(CampaignCommission.LEGACY_MESSAGE);
    }
}
