package mn.uziy.backend.admin

import mn.uziy.backend.company.CampaignDto
import mn.uziy.backend.domain.*
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
