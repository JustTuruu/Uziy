package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import org.junit.jupiter.api.Test;

class ModerationStrategyTest {

    private final OffsetDateTime now = OffsetDateTime.ofInstant(Instant.parse("2026-10-06T10:00:00Z"), ZoneOffset.UTC);
    private final ModerationStrategyRegistry registry = new ModerationStrategyRegistry(
            List.of(new ApproveCampaignStrategy(), new RejectCampaignStrategy()));

    @Test
    void approveTargetsActiveAndStampsTheCampaign() {
        CampaignEntity c = AdminTestData.campaign(1, CampaignStatus.PENDING);
        new ApproveCampaignStrategy().apply(c, now);
        assertThat(c.getStatus()).isEqualTo(CampaignStatus.ACTIVE);
        assertThat(c.getUpdatedAt()).isEqualTo(now);
    }

    @Test
    void rejectTargetsRejectedAndStampsTheCampaign() {
        CampaignEntity c = AdminTestData.campaign(1, CampaignStatus.PENDING);
        new RejectCampaignStrategy().apply(c, now);
        assertThat(c.getStatus()).isEqualTo(CampaignStatus.REJECTED);
        assertThat(c.getUpdatedAt()).isEqualTo(now);
    }

    @Test
    void registryResolvesActiveAndRejected() {
        assertThat(registry.find(CampaignStatus.ACTIVE)).containsInstanceOf(ApproveCampaignStrategy.class);
        assertThat(registry.find(CampaignStatus.REJECTED)).containsInstanceOf(RejectCampaignStrategy.class);
    }

    @Test
    void registryReturnsEmptyForNonModerationStatuses() {
        for (CampaignStatus s : List.of(CampaignStatus.PAUSED, CampaignStatus.PENDING,
                CampaignStatus.COMPLETED, CampaignStatus.AWAITING_PAYMENT)) {
            assertThat(registry.find(s)).isEmpty();
        }
    }
}
