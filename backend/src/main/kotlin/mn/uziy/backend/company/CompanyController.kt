package mn.uziy.backend.company

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import mn.uziy.backend.config.AppProperties
import mn.uziy.backend.domain.*
import mn.uziy.backend.pricing.CampaignPricing
import mn.uziy.backend.pricing.PricingMode
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.http.HttpStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

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
    /** Amount charged (= payable P), whole ₮. */
    val totalBudget: Double,
    val remainingBudget: Double,
    /** C — what one viewer costs the company (reward + platform commission). */
    val costPerView: Double,
    /** R — what one viewer receives. */
    val rewardPerUser: Double,
    val status: CampaignStatus,
    val createdAt: OffsetDateTime,
    /** N — viewers the budget buys. */
    val targetViewers: Int?,
    /** Commission snapshot at creation; null for legacy (pre-V5) campaigns. */
    val commissionPercent: Int?,
    val paidAt: OffsetDateTime?,
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
            targetViewers = c.targetViewers,
            commissionPercent = c.commissionPercent,
            paidAt = c.paidAt,
        )
    }
}

/**
 * Pricing inputs: `totalBudget` plus EXACTLY ONE of `targetViewers` (VIEWERS
 * mode) or `rewardPerUser` (REWARD mode). The server derives everything else
 * with the current platform commission — cost-per-view is never taken from
 * the client (an unknown `costPerView` field in the JSON is ignored).
 */
@JsonIgnoreProperties(ignoreUnknown = true)
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
    /** B, whole ₮. Nullable so a missing value gets the Mongolian pricing message. */
    val totalBudget: Double? = null,
    val targetViewers: Int? = null,
    /** R, whole ₮. */
    val rewardPerUser: Double? = null,
    val questions: List<NewQuestion> = emptyList(),
) {
    data class NewQuestion(
        val prompt: String,
        val type: String,          // SINGLE_CHOICE | MULTI_CHOICE | TEXT
        val options: List<String> = emptyList(),
        val required: Boolean = true,
    )
}

data class PaymentDto(
    val id: Long,
    val campaignId: Long,
    val campaignTitle: String,
    val amount: Double,
    val provider: PaymentProvider,
    val status: PaymentStatus,
    val reference: String,
    val createdAt: OffsetDateTime,
    val paidAt: OffsetDateTime?,
) {
    companion object {
        fun of(p: CampaignPaymentEntity, campaignTitle: String) = PaymentDto(
            id = p.id!!, campaignId = p.campaignId, campaignTitle = campaignTitle,
            amount = p.amount, provider = p.provider, status = p.status,
            reference = p.reference, createdAt = p.createdAt, paidAt = p.paidAt,
        )
    }
}

data class PayCampaignResponse(val campaign: CampaignDto, val payment: PaymentDto)

@RestController
@RequestMapping("/company")
@PreAuthorize("hasRole('COMPANY')")
class CompanyController(
    private val campaigns: CampaignRepository,
    private val questions: SurveyQuestionRepository,
    private val platformSettings: PlatformSettingsRepository,
    private val payments: CampaignPaymentRepository,
    private val props: AppProperties,
) {

    companion object {
        const val EXACTLY_ONE_DRIVER_MESSAGE =
            "Үзэгчийн тоо эсвэл нэг үзэгчийн урамшууллын аль нэгийг оруулна уу"
        const val WHOLE_TUGRIK_MESSAGE = "Дүнг бүхэл төгрөгөөр оруулна уу"
        const val AMOUNT_TOO_LARGE_MESSAGE = "Дүн хэт их байна"
        const val TOO_MANY_VIEWERS_MESSAGE = "Үзэгчийн тоо хэт их байна"
        const val DURATION_MESSAGE = "Видеоны урт 5–180 секунд байх ёстой"
        const val NO_QUESTIONS_MESSAGE = "Судалгаанд дор хаяж нэг асуулт оруулна уу"
        const val NOT_PAYABLE_MESSAGE =
            "Энэ аяны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй"
        const val PAYMENTS_UNAVAILABLE_MESSAGE = "Төлбөрийн систем хараахан холбогдоогүй байна"
        const val TRANSITION_MESSAGE = "Энэ төлөвөөс шилжих боломжгүй"

        /**
         * 10^15 ₮ — far beyond any real budget, and below 2^53 so every
         * whole-tögrög value survives the DOUBLE PRECISION money columns.
         */
        const val MAX_AMOUNT = 1_000_000_000_000_000L

        /** The only status changes a company may make on its own campaign. */
        val COMPANY_TRANSITIONS: Map<CampaignStatus, Set<CampaignStatus>> = mapOf(
            CampaignStatus.ACTIVE to setOf(CampaignStatus.PAUSED, CampaignStatus.COMPLETED),
            CampaignStatus.PAUSED to setOf(CampaignStatus.ACTIVE, CampaignStatus.COMPLETED),
        )

        private val REFERENCE_ZONE: ZoneId = ZoneId.of("Asia/Ulaanbaatar")
        private val REFERENCE_DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd")

        /** Invoice number shown to the company: UZ-<yyyyMMdd in Ulaanbaatar>-<campaignId>. */
        fun paymentReference(campaignId: Long, at: OffsetDateTime): String =
            "UZ-${at.atZoneSameInstant(REFERENCE_ZONE).format(REFERENCE_DATE)}-$campaignId"

        private fun badRequest(message: String) =
            ResponseStatusException(HttpStatus.BAD_REQUEST, message)

        private fun conflict(message: String) =
            ResponseStatusException(HttpStatus.CONFLICT, message)

        /** Postgres keeps microseconds — truncate so the response matches what is stored. */
        private fun now(): OffsetDateTime = OffsetDateTime.now().truncatedTo(ChronoUnit.MICROS)

        /**
         * JSON number → whole ₮. null → 0 (so the pricing function reports
         * the "enter a value" message). Fractions and absurd values → 400.
         */
        private fun wholeTugrik(value: Double?): Long {
            if (value == null) return 0
            if (!value.isFinite() || value % 1.0 != 0.0) throw badRequest(WHOLE_TUGRIK_MESSAGE)
            if (value > MAX_AMOUNT) throw badRequest(AMOUNT_TOO_LARGE_MESSAGE)
            return value.toLong()
        }
    }

    @GetMapping("/campaigns")
    fun list(@Auth principal: JwtPrincipal): List<CampaignDto> =
        campaigns.findAllByCompanyIdOrderByCreatedAtDesc(principal.userId).map(CampaignDto::of)

    @GetMapping("/campaigns/{id}")
    fun get(@PathVariable id: Long, @Auth principal: JwtPrincipal): CampaignDto =
        CampaignDto.of(ownedCampaign(id, principal))

    /**
     * Creates the campaign in AWAITING_PAYMENT. Pricing is recomputed here
     * from the CURRENT platform settings — the wizard's preview is advisory,
     * the numbers saved (and later charged) are the server's.
     */
    @PostMapping("/campaigns")
    @Transactional
    fun create(
        @Valid @RequestBody body: CreateCampaignReq,
        @Auth principal: JwtPrincipal,
    ): CampaignDto {
        val mode = when {
            body.targetViewers != null && body.rewardPerUser == null -> PricingMode.VIEWERS
            body.targetViewers == null && body.rewardPerUser != null -> PricingMode.REWARD
            else -> throw badRequest(EXACTLY_ONE_DRIVER_MESSAGE)
        }
        if (body.hasVideo) {
            if (body.durationSeconds !in 5..180) throw badRequest(DURATION_MESSAGE)
        } else {
            if (body.questions.isEmpty()) throw badRequest(NO_QUESTIONS_MESSAGE)
        }

        val settings = platformSettings.current()
        val minReward = settings.minRewardPerViewer.toLong()
        val pricing = CampaignPricing.compute(
            mode = mode,
            budget = wholeTugrik(body.totalBudget),
            commissionPercent = settings.commissionPercent,
            minRewardPerViewer = minReward,
            targetViewers = body.targetViewers?.toLong(),
            rewardPerViewer = if (mode == PricingMode.REWARD) wholeTugrik(body.rewardPerUser) else null,
        )
        pricing.error?.let { throw badRequest(it.message(minReward)) }
        if (pricing.targetViewers > Int.MAX_VALUE) throw badRequest(TOO_MANY_VIEWERS_MESSAGE)

        val c = campaigns.save(CampaignEntity(
            companyId         = principal.userId,
            title             = body.title,
            videoUrl          = if (body.hasVideo) body.videoUrl else "",
            durationSeconds   = if (body.hasVideo) body.durationSeconds else 0,
            hasVideo          = body.hasVideo,
            targetGender      = body.targetGender,
            minAge            = body.minAge,
            maxAge            = body.maxAge,
            targetCity        = body.targetCity,
            // Only P = C × N is charged; any remainder of B is not.
            totalBudget       = pricing.payable.toDouble(),
            remainingBudget   = pricing.payable.toDouble(),
            costPerView       = pricing.costPerViewer.toDouble(),
            rewardPerUser     = pricing.rewardPerViewer.toDouble(),
            targetViewers     = pricing.targetViewers.toInt(),
            commissionPercent = pricing.commissionPercent,
            status            = CampaignStatus.AWAITING_PAYMENT,
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

    /**
     * Pay for one campaign (AWAITING_PAYMENT → PENDING, i.e. into the admin
     * moderation queue). Simulated for now: no money moves, the campaign is
     * marked paid instantly and a SIMULATED payment row is recorded.
     *
     * Race safety: the status flip is a conditional UPDATE (0 rows → 409), and
     * the partial unique index ux_campaign_payments_one_paid backs it up.
     */
    @PostMapping("/campaigns/{id}/pay")
    @Transactional
    fun pay(@PathVariable id: Long, @Auth principal: JwtPrincipal): PayCampaignResponse {
        val c = ownedCampaign(id, principal)
        if (c.status != CampaignStatus.AWAITING_PAYMENT) throw conflict(NOT_PAYABLE_MESSAGE)
        if (!props.payments.simulated)
            throw ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, PAYMENTS_UNAVAILABLE_MESSAGE)

        val paidAt = now()
        if (campaigns.tryMarkPaid(id, paidAt) == 0) throw conflict(NOT_PAYABLE_MESSAGE)

        val payment = try {
            payments.saveAndFlush(CampaignPaymentEntity(
                campaignId = id,
                companyId  = c.companyId,
                amount     = c.totalBudget,
                provider   = PaymentProvider.SIMULATED,
                status     = PaymentStatus.PAID,
                reference  = paymentReference(id, paidAt),
                createdAt  = paidAt,
                paidAt     = paidAt,
            ))
        } catch (_: DataIntegrityViolationException) {
            // Another PAID row already exists — the whole tx rolls back.
            throw conflict(NOT_PAYABLE_MESSAGE)
        }

        // `c` was detached by tryMarkPaid (clearAutomatically), so these
        // assignments only shape the response — they are not written back.
        c.status = CampaignStatus.PENDING
        c.paidAt = paidAt
        c.updatedAt = paidAt
        return PayCampaignResponse(
            campaign = CampaignDto.of(c),
            payment  = PaymentDto.of(payment, c.title),
        )
    }

    /** The caller's campaign payments, newest first. */
    @GetMapping("/payments")
    fun payments(@Auth principal: JwtPrincipal): List<PaymentDto> {
        val list = payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(principal.userId)
        val titles = campaigns.findAllById(list.map { it.campaignId }.distinct())
            .associate { it.id!! to it.title }
        return list.map { PaymentDto.of(it, titles[it.campaignId] ?: "") }
    }

    /**
     * Company-driven lifecycle: ACTIVE ⇄ PAUSED, ACTIVE|PAUSED → COMPLETED.
     * Everything else (notably PENDING → ACTIVE, which would skip moderation,
     * and anything out of AWAITING_PAYMENT, which would skip payment) is 409.
     */
    @PatchMapping("/campaigns/{id}/status")
    @Transactional
    fun setStatus(
        @PathVariable id: Long,
        @RequestParam status: CampaignStatus,
        @Auth principal: JwtPrincipal,
    ): CampaignDto {
        val c = ownedCampaign(id, principal)
        val from = c.status
        if (status !in COMPANY_TRANSITIONS[from].orEmpty()) throw conflict(TRANSITION_MESSAGE)

        val at = now()
        if (campaigns.tryTransition(id, from, status, at) == 0) throw conflict(TRANSITION_MESSAGE)

        // Detached (clearAutomatically) — response only, not written back.
        c.status = status
        c.updatedAt = at
        return CampaignDto.of(c)
    }

    private fun ownedCampaign(id: Long, principal: JwtPrincipal): CampaignEntity {
        val c = campaigns.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND)
        }
        if (c.companyId != principal.userId)
            throw ResponseStatusException(HttpStatus.FORBIDDEN)
        return c
    }
}
