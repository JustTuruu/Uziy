package mn.uziy.backend.settings

import mn.uziy.backend.domain.PlatformSettingsEntity
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
