package mn.uziy.backend.settings

import mn.uziy.backend.domain.PlatformSettingsEntity
import mn.uziy.backend.domain.PlatformSettingsRepository
import mn.uziy.backend.domain.current
import mn.uziy.backend.pricing.CampaignPricing
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.http.HttpStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.OffsetDateTime

data class PlatformSettingsDto(
    val commissionPercent: Int,
    val minRewardPerViewer: Int,
    val updatedAt: OffsetDateTime,
) {
    companion object {
        fun of(e: PlatformSettingsEntity) = PlatformSettingsDto(
            commissionPercent  = e.commissionPercent,
            minRewardPerViewer = e.minRewardPerViewer,
            updatedAt          = e.updatedAt,
        )
    }
}

/** Both fields required — nullable only so a missing field gets our Mongolian 400. */
data class UpdatePlatformSettingsReq(
    val commissionPercent: Int? = null,
    val minRewardPerViewer: Int? = null,
)

@RestController
class PlatformSettingsController(
    private val repo: PlatformSettingsRepository,
) {

    companion object {
        const val COMMISSION_RANGE_MESSAGE = "Платформын шимтгэл 1–90% хооронд байх ёстой"
        const val MIN_REWARD_MESSAGE = "Нэг үзэгчид олгох хамгийн бага урамшуулал 1 ₮-өөс багагүй байх ёстой"
    }

    /**
     * Public read — the company wizard needs the commission and the minimum
     * reward to preview pricing before the campaign is created. Contains no
     * sensitive data.
     */
    @GetMapping("/platform-settings")
    fun get(): PlatformSettingsDto = PlatformSettingsDto.of(repo.current())

    @PatchMapping("/admin/platform-settings")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    fun update(
        @RequestBody body: UpdatePlatformSettingsReq,
        @Auth admin: JwtPrincipal,
    ): PlatformSettingsDto {
        val commission = body.commissionPercent
        if (commission == null ||
            commission !in CampaignPricing.MIN_COMMISSION_PERCENT..CampaignPricing.MAX_COMMISSION_PERCENT
        ) throw ResponseStatusException(HttpStatus.BAD_REQUEST, COMMISSION_RANGE_MESSAGE)

        val minReward = body.minRewardPerViewer
        if (minReward == null || minReward < 1)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, MIN_REWARD_MESSAGE)

        // Only affects campaigns created from now on — existing campaigns
        // keep the reward/cost (and commission snapshot) they were priced with.
        val e = repo.current().apply {
            commissionPercent  = commission
            minRewardPerViewer = minReward
            updatedAt          = OffsetDateTime.now()
            updatedBy          = admin.userId
        }
        return PlatformSettingsDto.of(repo.save(e))
    }
}
