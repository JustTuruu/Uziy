package mn.uziy.backend.settings

import jakarta.validation.Valid
import jakarta.validation.constraints.Positive
import mn.uziy.backend.domain.PlatformSettingsEntity
import mn.uziy.backend.domain.PlatformSettingsRepository
import mn.uziy.backend.domain.current
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.http.HttpStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.OffsetDateTime

data class PlatformSettingsDto(
    val surveyOnlyCostPerResponse: Double,
    val surveyOnlyRewardPerUser: Double,
    val updatedAt: OffsetDateTime,
) {
    companion object {
        fun of(e: PlatformSettingsEntity) = PlatformSettingsDto(
            surveyOnlyCostPerResponse = e.surveyOnlyCostPerResponse,
            surveyOnlyRewardPerUser   = e.surveyOnlyRewardPerUser,
            updatedAt                 = e.updatedAt,
        )
    }
}

data class UpdatePlatformSettingsReq(
    @field:Positive val surveyOnlyCostPerResponse: Double,
    @field:Positive val surveyOnlyRewardPerUser: Double,
)

@RestController
class PlatformSettingsController(
    private val repo: PlatformSettingsRepository,
) {

    /**
     * Public read — companies need this when they render the survey-only
     * option in the campaign wizard, and viewers may want to preview the
     * reward before answering. Contains no sensitive data.
     */
    @GetMapping("/platform-settings")
    fun get(): PlatformSettingsDto = PlatformSettingsDto.of(repo.current())

    @PatchMapping("/admin/platform-settings")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    fun update(
        @Valid @RequestBody body: UpdatePlatformSettingsReq,
        @Auth admin: JwtPrincipal,
    ): PlatformSettingsDto {
        if (body.surveyOnlyRewardPerUser >= body.surveyOnlyCostPerResponse) {
            throw ResponseStatusException(
                HttpStatus.BAD_REQUEST,
                "reward must be strictly less than cost (platform commission = cost - reward)",
            )
        }
        val e = repo.current().apply {
            surveyOnlyCostPerResponse = body.surveyOnlyCostPerResponse
            surveyOnlyRewardPerUser   = body.surveyOnlyRewardPerUser
            updatedAt                 = OffsetDateTime.now()
            updatedBy                 = admin.userId
        }
        return PlatformSettingsDto.of(repo.save(e))
    }
}
