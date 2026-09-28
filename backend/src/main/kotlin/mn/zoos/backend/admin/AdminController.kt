package mn.zoos.backend.admin

import mn.zoos.backend.company.CampaignDto
import mn.zoos.backend.config.AppProperties
import mn.zoos.backend.domain.*
import mn.zoos.backend.security.Auth
import mn.zoos.backend.security.JwtPrincipal
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
    val pendingCampaigns: Long,
    val pendingPayouts: Long,
    val commissionRate: Double,
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
)

@RestController
@RequestMapping("/admin")
@PreAuthorize("hasRole('ADMIN')")
class AdminController(
    private val users: UserRepository,
    private val campaigns: CampaignRepository,
    private val payouts: PayoutRepository,
    private val props: AppProperties,
) {

    @GetMapping("/stats")
    fun stats(): AdminStats = AdminStats(
        totalUsers = users.count(),
        totalCampaigns = campaigns.count(),
        activeCampaigns = campaigns
            .findAllByStatusOrderByCreatedAtDesc(CampaignStatus.ACTIVE).size.toLong(),
        pendingCampaigns = campaigns
            .findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING).size.toLong(),
        pendingPayouts = payouts
            .findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING).size.toLong(),
        commissionRate = props.reward.commissionRate,
    )

    @GetMapping("/users")
    fun listUsers(): List<UserDto> = users.findAll().map {
        UserDto(
            id = it.id!!, phoneNumber = it.phoneNumber, role = it.role,
            gender = it.gender, age = it.age, city = it.city,
            balance = it.balance, isVerified = it.isVerified,
            companyName = it.companyName, createdAt = it.createdAt,
        )
    }

    @PatchMapping("/users/{id}/verify")
    fun verify(@PathVariable id: Long): UserDto {
        val u = users.findById(id).orElseThrow()
        u.isVerified = true
        users.save(u)
        return UserDto(
            id = u.id!!, phoneNumber = u.phoneNumber, role = u.role,
            gender = u.gender, age = u.age, city = u.city,
            balance = u.balance, isVerified = u.isVerified,
            companyName = u.companyName, createdAt = u.createdAt,
        )
    }

    @GetMapping("/campaigns")
    fun listCampaigns(
        @RequestParam(required = false) status: CampaignStatus?,
    ): List<CampaignDto> =
        (status?.let { campaigns.findAllByStatusOrderByCreatedAtDesc(it) }
            ?: campaigns.findAll())
            .map(CampaignDto::of)

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
        val c = campaigns.findById(id).orElseThrow()
        if (c.status != CampaignStatus.PENDING)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Already moderated")
        c.status = decision
        c.updatedAt = OffsetDateTime.now()
        return CampaignDto.of(campaigns.save(c))
    }
}
