package mn.uziy.backend.company

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Positive
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.http.HttpStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.OffsetDateTime

data class CampaignDto(
    val id: Long,
    val title: String,
    val videoUrl: String,
    val durationSeconds: Int,
    val hasVideo: Boolean,
    val targetGender: TargetGender,
    val minAge: Int,
    val maxAge: Int,
    val targetCity: String,
    val totalBudget: Double,
    val remainingBudget: Double,
    val costPerView: Double,
    val rewardPerUser: Double,
    val status: CampaignStatus,
    val createdAt: OffsetDateTime,
) {
    companion object {
        fun of(c: CampaignEntity) = CampaignDto(
            id = c.id!!, title = c.title, videoUrl = c.videoUrl,
            durationSeconds = c.durationSeconds,
            hasVideo = c.hasVideo,
            targetGender = c.targetGender,
            minAge = c.minAge, maxAge = c.maxAge, targetCity = c.targetCity,
            totalBudget = c.totalBudget, remainingBudget = c.remainingBudget,
            costPerView = c.costPerView, rewardPerUser = c.rewardPerUser,
            status = c.status, createdAt = c.createdAt,
        )
    }
}

data class CreateCampaignReq(
    @field:NotBlank val title: String,
    val videoUrl: String = "",
    /** Set false for survey-only campaigns (videoUrl + durationSeconds ignored). */
    val hasVideo: Boolean = true,
    val durationSeconds: Int = 0,
    val targetGender: TargetGender = TargetGender.ALL,
    val minAge: Int = 0,
    val maxAge: Int = 100,
    val targetCity: String = "ALL",
    @field:Positive val totalBudget: Double,
    @field:Positive val costPerView: Double,
    @field:Positive val rewardPerUser: Double,
    val questions: List<NewQuestion> = emptyList(),
) {
    data class NewQuestion(
        val prompt: String,
        val type: String,          // SINGLE_CHOICE | MULTI_CHOICE | TEXT
        val options: List<String> = emptyList(),
        val required: Boolean = true,
    )
}

@RestController
@RequestMapping("/company")
@PreAuthorize("hasRole('COMPANY')")
class CompanyController(
    private val campaigns: CampaignRepository,
    private val questions: SurveyQuestionRepository,
) {

    @GetMapping("/campaigns")
    fun list(@Auth principal: JwtPrincipal): List<CampaignDto> =
        campaigns.findAllByCompanyIdOrderByCreatedAtDesc(principal.userId).map(CampaignDto::of)

    @GetMapping("/campaigns/{id}")
    fun get(@PathVariable id: Long, @Auth principal: JwtPrincipal): CampaignDto {
        val c = campaigns.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND)
        }
        if (c.companyId != principal.userId)
            throw ResponseStatusException(HttpStatus.FORBIDDEN)
        return CampaignDto.of(c)
    }

    @PostMapping("/campaigns")
    @Transactional
    fun create(
        @Valid @RequestBody body: CreateCampaignReq,
        @Auth principal: JwtPrincipal,
    ): CampaignDto {
        if (body.rewardPerUser >= body.costPerView)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST,
                "rewardPerUser must be strictly less than costPerView")
        if (body.hasVideo) {
            if (body.durationSeconds !in 5..180)
                throw ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "durationSeconds must be 5..180 for video campaigns")
        } else {
            if (body.questions.isEmpty())
                throw ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "survey-only campaigns must include at least one survey question")
        }

        val c = campaigns.save(CampaignEntity(
            companyId       = principal.userId,
            title           = body.title,
            videoUrl        = if (body.hasVideo) body.videoUrl else "",
            durationSeconds = if (body.hasVideo) body.durationSeconds else 0,
            hasVideo        = body.hasVideo,
            targetGender    = body.targetGender,
            minAge          = body.minAge,
            maxAge          = body.maxAge,
            targetCity      = body.targetCity,
            totalBudget     = body.totalBudget,
            remainingBudget = body.totalBudget,
            costPerView     = body.costPerView,
            rewardPerUser   = body.rewardPerUser,
            status          = CampaignStatus.PENDING,
        ))
        body.questions.forEachIndexed { i, q ->
            questions.save(SurveyQuestionEntity(
                campaignId = c.id!!,
                position   = i + 1,
                prompt     = q.prompt,
                qType      = q.type,
                optionsJson = q.options.joinToString(
                    prefix = "[", postfix = "]",
                ) { "\"${it.replace("\"", "\\\"")}\"" },
                required   = q.required,
            ))
        }
        return CampaignDto.of(c)
    }

    @PatchMapping("/campaigns/{id}/status")
    fun setStatus(
        @PathVariable id: Long,
        @RequestParam status: CampaignStatus,
        @Auth principal: JwtPrincipal,
    ): CampaignDto {
        val c = campaigns.findById(id).orElseThrow()
        if (c.companyId != principal.userId)
            throw ResponseStatusException(HttpStatus.FORBIDDEN)
        if (status !in setOf(CampaignStatus.ACTIVE, CampaignStatus.PAUSED, CampaignStatus.COMPLETED))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Only ACTIVE/PAUSED/COMPLETED allowed")
        c.status = status
        c.updatedAt = OffsetDateTime.now()
        return CampaignDto.of(campaigns.save(c))
    }
}
