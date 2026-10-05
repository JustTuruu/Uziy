package mn.uziy.backend.admin

import mn.uziy.backend.common.BadRequestException
import mn.uziy.backend.common.ConflictException
import mn.uziy.backend.common.NotFoundException
import mn.uziy.backend.company.CampaignDto
import mn.uziy.backend.domain.CampaignRepository
import mn.uziy.backend.domain.CampaignStatus
import mn.uziy.backend.domain.UserRepository
import mn.uziy.backend.domain.ViewHistoryRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime

/** The admin's campaign oversight: browse, inspect, approve / reject. */
interface CampaignModerationService {
    fun list(status: CampaignStatus?, companyId: Long?): List<CampaignDto>
    fun get(campaignId: Long): CampaignDetailDto

    /** Only paid campaigns (PENDING) can be moderated, to ACTIVE or REJECTED. */
    fun moderate(campaignId: Long, decision: CampaignStatus): CampaignDto
}

@Service
class CampaignModerationServiceImpl(
    private val campaigns: CampaignRepository,
    private val users: UserRepository,
    private val history: ViewHistoryRepository,
) : CampaignModerationService {

    override fun list(status: CampaignStatus?, companyId: Long?): List<CampaignDto> {
        val list = when {
            companyId != null -> campaigns
                .findAllByCompanyIdOrderByCreatedAtDesc(companyId)
                .let { xs -> if (status != null) xs.filter { it.status == status } else xs }
            status != null -> campaigns.findAllByStatusOrderByCreatedAtDesc(status)
            else -> campaigns.findAll().sortedByDescending { it.createdAt }
        }
        return list.map(CampaignDto::of)
    }

    override fun get(campaignId: Long): CampaignDetailDto {
        val c = campaigns.findById(campaignId).orElseThrow {
            NotFoundException("Campaign not found")
        }
        val owner = users.findById(c.companyId).orElse(null)
        return CampaignDetailDto(
            campaign = CampaignDto.of(c),
            companyId = c.companyId,
            companyName = owner?.companyName,
            completedViews = history.countByCampaignId(c.id!!),
            spentBudget = c.totalBudget - c.remainingBudget,
        )
    }

    @Transactional
    override fun moderate(campaignId: Long, decision: CampaignStatus): CampaignDto {
        if (decision !in setOf(CampaignStatus.ACTIVE, CampaignStatus.REJECTED))
            throw BadRequestException("Only ACTIVE or REJECTED allowed for moderation")
        val c = campaigns.findById(campaignId).orElseThrow {
            NotFoundException("Campaign not found")
        }
        if (c.status == CampaignStatus.AWAITING_PAYMENT) throw ConflictException(UNPAID_MESSAGE)
        if (c.status != CampaignStatus.PENDING) throw ConflictException("Already moderated")
        c.status = decision
        c.updatedAt = OffsetDateTime.now()
        return CampaignDto.of(campaigns.save(c))
    }

    companion object {
        const val UNPAID_MESSAGE = "Төлбөр нь төлөгдөөгүй аяныг хянах боломжгүй"
    }
}
