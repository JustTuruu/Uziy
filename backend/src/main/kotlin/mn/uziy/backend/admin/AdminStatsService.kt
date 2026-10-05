package mn.uziy.backend.admin

import mn.uziy.backend.domain.*
import org.springframework.stereotype.Service

/** Platform-wide counters for the admin dashboard. */
interface AdminStatsService {
    fun stats(): AdminStats
}

@Service
class AdminStatsServiceImpl(
    private val users: UserRepository,
    private val campaigns: CampaignRepository,
    private val payouts: PayoutRepository,
    private val platformSettings: PlatformSettingsRepository,
) : AdminStatsService {

    override fun stats(): AdminStats {
        val commissionPercent = platformSettings.current().commissionPercent
        return AdminStats(
            totalUsers = users.count(),
            totalCampaigns = campaigns.count(),
            activeCampaigns = countCampaigns(CampaignStatus.ACTIVE),
            pendingCampaigns = countCampaigns(CampaignStatus.PENDING),
            awaitingPaymentCampaigns = countCampaigns(CampaignStatus.AWAITING_PAYMENT),
            pendingPayouts = payouts
                .findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING).size.toLong(),
            commissionRate = commissionPercent / 100.0,
            commissionPercent = commissionPercent,
        )
    }

    private fun countCampaigns(status: CampaignStatus): Long =
        campaigns.findAllByStatusOrderByCreatedAtDesc(status).size.toLong()
}
