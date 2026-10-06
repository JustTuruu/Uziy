package mn.uziy.backend.admin;

import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.PlatformSettings;
import mn.uziy.backend.domain.PlatformSettingsRepository;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class AdminStatsServiceImpl implements AdminStatsService {

    private static final double PERCENT_DIVISOR = 100.0;

    private final UserRepository users;
    private final CampaignRepository campaigns;
    private final PayoutRepository payouts;
    private final PlatformSettingsRepository platformSettings;

    public AdminStatsServiceImpl(UserRepository users, CampaignRepository campaigns,
                                 PayoutRepository payouts, PlatformSettingsRepository platformSettings) {
        this.users = users;
        this.campaigns = campaigns;
        this.payouts = payouts;
        this.platformSettings = platformSettings;
    }

    @Override
    public AdminStats stats() {
        int commissionPercent = PlatformSettings.current(platformSettings).getCommissionPercent();
        return new AdminStats(
                users.count(),
                campaigns.count(),
                countCampaigns(CampaignStatus.ACTIVE),
                countCampaigns(CampaignStatus.PENDING),
                countCampaigns(CampaignStatus.AWAITING_PAYMENT),
                payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING).size(),
                commissionPercent / PERCENT_DIVISOR,
                commissionPercent);
    }

    private long countCampaigns(CampaignStatus status) {
        return campaigns.findAllByStatusOrderByCreatedAtDesc(status).size();
    }
}
