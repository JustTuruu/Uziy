package mn.uziy.backend.admin

import mn.uziy.backend.company.CampaignDto
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.http.HttpStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.OffsetDateTime

data class AdminStats(
    val totalUsers: Long,
    val totalCampaigns: Long,
    val activeCampaigns: Long,
    /** Paid, waiting for moderation. */
    val pendingCampaigns: Long,
    /** Created but not yet paid by the company. */
    val awaitingPaymentCampaigns: Long,
    val pendingPayouts: Long,
    /** Current platform commission as a fraction (0.30) — mirrors [commissionPercent]. */
    val commissionRate: Double,
    /** Current platform commission, whole percent (platform_settings). */
    val commissionPercent: Int,
)

data class UserDto(
    val id: Long,
    val phoneNumber: String,
    val role: Role,
    val gender: Gender?,
    val age: Int?,
    val city: String?,
    val balance: Double,
    val isVerified: Boolean,
    val companyName: String?,
    val createdAt: OffsetDateTime,
) {
    companion object {
        fun of(u: UserEntity) = UserDto(
            id = u.id!!, phoneNumber = u.phoneNumber, role = u.role,
            gender = u.gender, age = u.age, city = u.city,
            balance = u.balance, isVerified = u.isVerified,
            companyName = u.companyName, createdAt = u.createdAt,
        )
    }
}

/**
 * Extended campaign shape returned by /admin/campaigns/{id} — carries the
 * completion counter and owning company name that the list DTO leaves off.
 */
data class CampaignDetailDto(
    val campaign: CampaignDto,
    val companyId: Long,
    val companyName: String?,
    val completedViews: Long,
    val spentBudget: Double,
)

@RestController
@RequestMapping("/admin")
@PreAuthorize("hasRole('ADMIN')")
class AdminController(
    private val users: UserRepository,
    private val campaigns: CampaignRepository,
    private val history: ViewHistoryRepository,
    private val payouts: PayoutRepository,
    private val platformSettings: PlatformSettingsRepository,
) {

    companion object {
        const val UNPAID_MESSAGE = "Төлбөр нь төлөгдөөгүй аяныг хянах боломжгүй"
    }

    @GetMapping("/stats")
    fun stats(): AdminStats {
        val commissionPercent = platformSettings.current().commissionPercent
        return AdminStats(
            totalUsers = users.count(),
            totalCampaigns = campaigns.count(),
            activeCampaigns = campaigns
                .findAllByStatusOrderByCreatedAtDesc(CampaignStatus.ACTIVE).size.toLong(),
            pendingCampaigns = campaigns
                .findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING).size.toLong(),
            awaitingPaymentCampaigns = campaigns
                .findAllByStatusOrderByCreatedAtDesc(CampaignStatus.AWAITING_PAYMENT).size.toLong(),
            pendingPayouts = payouts
                .findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING).size.toLong(),
            commissionRate = commissionPercent / 100.0,
            commissionPercent = commissionPercent,
        )
    }

    @GetMapping("/users")
    fun listUsers(): List<UserDto> =
        users.findAll().map(UserDto::of)

    @GetMapping("/users/{id}")
    fun getUser(@PathVariable id: Long): UserDto =
        UserDto.of(users.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        })

    @PatchMapping("/users/{id}/verify")
    fun verify(@PathVariable id: Long): UserDto {
        val u = users.findById(id).orElseThrow()
        u.isVerified = true
        return UserDto.of(users.save(u))
    }

    @GetMapping("/campaigns")
    fun listCampaigns(
        @RequestParam(required = false) status: CampaignStatus?,
        @RequestParam(required = false) companyId: Long?,
    ): List<CampaignDto> {
        val list = when {
            companyId != null -> campaigns
                .findAllByCompanyIdOrderByCreatedAtDesc(companyId)
                .let { xs -> if (status != null) xs.filter { it.status == status } else xs }
            status != null -> campaigns.findAllByStatusOrderByCreatedAtDesc(status)
            else -> campaigns.findAll().sortedByDescending { it.createdAt }
        }
        return list.map(CampaignDto::of)
    }

    @GetMapping("/campaigns/{id}")
    fun getCampaign(@PathVariable id: Long): CampaignDetailDto {
        val c = campaigns.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found")
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

    @PatchMapping("/campaigns/{id}/moderate")
    @Transactional
    fun moderate(
        @PathVariable id: Long,
        @RequestParam decision: CampaignStatus,
        @Auth admin: JwtPrincipal,
    ): CampaignDto {
        if (decision !in setOf(CampaignStatus.ACTIVE, CampaignStatus.REJECTED))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Only ACTIVE or REJECTED allowed for moderation")
        val c = campaigns.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found")
        }
        // Only paid campaigns (PENDING) reach moderation.
        if (c.status == CampaignStatus.AWAITING_PAYMENT)
            throw ResponseStatusException(HttpStatus.CONFLICT, UNPAID_MESSAGE)
        if (c.status != CampaignStatus.PENDING)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Already moderated")
        c.status = decision
        c.updatedAt = OffsetDateTime.now()
        return CampaignDto.of(campaigns.save(c))
    }
}
