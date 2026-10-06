package mn.uziy.backend.admin;

import static mn.uziy.backend.admin.AdminTestData.campaign;
import static mn.uziy.backend.admin.AdminTestData.payout;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.stream.LongStream;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.PlatformSettingsEntity;
import mn.uziy.backend.domain.PlatformSettingsRepository;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;

class AdminStatsServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final PayoutRepository payouts = mock(PayoutRepository.class);
    private final PlatformSettingsRepository platformSettings = mock(PlatformSettingsRepository.class);
    private final AdminStatsServiceImpl service =
            new AdminStatsServiceImpl(users, campaigns, payouts, platformSettings);

    private void stubCampaigns(CampaignStatus status, int count) {
        when(campaigns.findAllByStatusOrderByCreatedAtDesc(status)).thenReturn(
                LongStream.rangeClosed(1, count).mapToObj(i -> campaign(i, status)).toList());
    }

    @Test
    void statsAggregatesCountsAndTheCommissionFromPlatformSettings() {
        PlatformSettingsEntity settings = new PlatformSettingsEntity();
        settings.setId(1);
        settings.setCommissionPercent(35);
        settings.setMinRewardPerViewer(100);
        when(platformSettings.findById(1)).thenReturn(Optional.of(settings));
        when(users.count()).thenReturn(24_580L);
        when(campaigns.count()).thenReturn(147L);
        stubCampaigns(CampaignStatus.ACTIVE, 38);
        stubCampaigns(CampaignStatus.PENDING, 5);
        stubCampaigns(CampaignStatus.AWAITING_PAYMENT, 2);
        when(payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING)).thenReturn(
                LongStream.rangeClosed(1, 3).mapToObj(AdminTestData::payout).toList());

        AdminStats s = service.stats();

        assertThat(s.totalUsers()).isEqualTo(24_580);
        assertThat(s.totalCampaigns()).isEqualTo(147);
        assertThat(s.activeCampaigns()).isEqualTo(38);
        assertThat(s.pendingCampaigns()).isEqualTo(5);
        assertThat(s.awaitingPaymentCampaigns()).isEqualTo(2);
        assertThat(s.pendingPayouts()).isEqualTo(3);
        assertThat(s.commissionRate()).isEqualTo(0.35);
        assertThat(s.commissionPercent()).isEqualTo(35);
    }
}
