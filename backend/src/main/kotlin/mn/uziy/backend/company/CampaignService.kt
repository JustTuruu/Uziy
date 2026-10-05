package mn.uziy.backend.company

import mn.uziy.backend.common.BadRequestException
import mn.uziy.backend.common.ConflictException
import mn.uziy.backend.company.CompanyMessages.AMOUNT_TOO_LARGE_MESSAGE
import mn.uziy.backend.company.CompanyMessages.DURATION_MESSAGE
import mn.uziy.backend.company.CompanyMessages.EXACTLY_ONE_DRIVER_MESSAGE
import mn.uziy.backend.company.CompanyMessages.NO_QUESTIONS_MESSAGE
import mn.uziy.backend.company.CompanyMessages.TOO_MANY_VIEWERS_MESSAGE
import mn.uziy.backend.company.CompanyMessages.TRANSITION_MESSAGE
import mn.uziy.backend.company.CompanyMessages.WHOLE_TUGRIK_MESSAGE
import mn.uziy.backend.domain.*
import mn.uziy.backend.pricing.CampaignPricing
import mn.uziy.backend.pricing.PricingMode
import mn.uziy.backend.pricing.PricingResult
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.time.temporal.ChronoUnit

/** A company's campaigns: create, read and drive through the lifecycle. */
interface CampaignService {
    fun list(companyId: Long): List<CampaignDto>

    fun get(companyId: Long, campaignId: Long): CampaignDto

    /**
     * Creates the campaign in AWAITING_PAYMENT. Pricing is recomputed here
     * from the CURRENT platform settings — the wizard's preview is advisory,
     * the numbers saved (and later charged) are the server's.
     */
    fun create(companyId: Long, req: CreateCampaignReq): CampaignDto

    /**
     * Company-driven lifecycle: ACTIVE ⇄ PAUSED, ACTIVE|PAUSED → COMPLETED.
     * Everything else (notably PENDING → ACTIVE, which would skip moderation,
     * and anything out of AWAITING_PAYMENT, which would skip payment) is a conflict.
     */
    fun setStatus(companyId: Long, campaignId: Long, status: CampaignStatus): CampaignDto
}

@Service
class CampaignServiceImpl(
    private val campaigns: CampaignRepository,
    private val questions: SurveyQuestionRepository,
    private val platformSettings: PlatformSettingsRepository,
) : CampaignService {

    override fun list(companyId: Long): List<CampaignDto> =
        campaigns.findAllByCompanyIdOrderByCreatedAtDesc(companyId).map(CampaignDto::of)

    override fun get(companyId: Long, campaignId: Long): CampaignDto =
        CampaignDto.of(campaigns.owned(companyId, campaignId))

    @Transactional
    override fun create(companyId: Long, req: CreateCampaignReq): CampaignDto {
        val mode = pricingMode(req)
        validateShape(req)
        val pricing = price(req, mode)

        val c = campaigns.save(CampaignEntity(
            companyId         = companyId,
            title             = req.title,
            videoUrl          = if (req.hasVideo) req.videoUrl else "",
            durationSeconds   = if (req.hasVideo) req.durationSeconds else 0,
            hasVideo          = req.hasVideo,
            targetGender      = req.targetGender,
            minAge            = req.minAge,
            maxAge            = req.maxAge,
            targetCity        = req.targetCity,
            // Only P = C × N is charged; any remainder of B is not.
            totalBudget       = pricing.payable.toDouble(),
            remainingBudget   = pricing.payable.toDouble(),
            costPerView       = pricing.costPerViewer.toDouble(),
            rewardPerUser     = pricing.rewardPerViewer.toDouble(),
            targetViewers     = pricing.targetViewers.toInt(),
            commissionPercent = pricing.commissionPercent,
            status            = CampaignStatus.AWAITING_PAYMENT,
        ))
        saveQuestions(c.id!!, req.questions)
        return CampaignDto.of(c)
    }

    @Transactional
    override fun setStatus(companyId: Long, campaignId: Long, status: CampaignStatus): CampaignDto {
        val c = campaigns.owned(companyId, campaignId)
        val from = c.status
        if (status !in COMPANY_TRANSITIONS[from].orEmpty()) throw ConflictException(TRANSITION_MESSAGE)

        val at = now()
        if (campaigns.tryTransition(campaignId, from, status, at) == 0)
            throw ConflictException(TRANSITION_MESSAGE)

        // Detached (clearAutomatically) — response only, not written back.
        c.status = status
        c.updatedAt = at
        return CampaignDto.of(c)
    }

    // --- create() steps ------------------------------------------------------

    /** Exactly one of targetViewers / rewardPerUser drives the pricing. */
    private fun pricingMode(req: CreateCampaignReq): PricingMode = when {
        req.targetViewers != null && req.rewardPerUser == null -> PricingMode.VIEWERS
        req.targetViewers == null && req.rewardPerUser != null -> PricingMode.REWARD
        else -> throw BadRequestException(EXACTLY_ONE_DRIVER_MESSAGE)
    }

    private fun validateShape(req: CreateCampaignReq) {
        if (req.hasVideo) {
            if (req.durationSeconds !in 5..180) throw BadRequestException(DURATION_MESSAGE)
        } else {
            if (req.questions.isEmpty()) throw BadRequestException(NO_QUESTIONS_MESSAGE)
        }
    }

    private fun price(req: CreateCampaignReq, mode: PricingMode): PricingResult {
        val settings = platformSettings.current()
        val minReward = settings.minRewardPerViewer.toLong()
        val pricing = CampaignPricing.compute(
            mode = mode,
            budget = wholeTugrik(req.totalBudget),
            commissionPercent = settings.commissionPercent,
            minRewardPerViewer = minReward,
            targetViewers = req.targetViewers?.toLong(),
            rewardPerViewer = if (mode == PricingMode.REWARD) wholeTugrik(req.rewardPerUser) else null,
        )
        pricing.error?.let { throw BadRequestException(it.message(minReward)) }
        if (pricing.targetViewers > Int.MAX_VALUE) throw BadRequestException(TOO_MANY_VIEWERS_MESSAGE)
        return pricing
    }

    private fun saveQuestions(campaignId: Long, new: List<CreateCampaignReq.NewQuestion>) {
        new.forEachIndexed { i, q ->
            questions.save(SurveyQuestionEntity(
                campaignId = campaignId,
                position   = i + 1,
                prompt     = q.prompt,
                qType      = q.type,
                optionsJson = q.options.joinToString(
                    prefix = "[", postfix = "]",
                ) { "\"${it.replace("\"", "\\\"")}\"" },
                required   = q.required,
            ))
        }
    }

    companion object {
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

        /** Postgres keeps microseconds — truncate so the response matches what is stored. */
        internal fun now(): OffsetDateTime = OffsetDateTime.now().truncatedTo(ChronoUnit.MICROS)

        /**
         * JSON number → whole ₮. null → 0 (so the pricing function reports
         * the "enter a value" message). Fractions and absurd values → 400.
         */
        private fun wholeTugrik(value: Double?): Long {
            if (value == null) return 0
            if (!value.isFinite() || value % 1.0 != 0.0) throw BadRequestException(WHOLE_TUGRIK_MESSAGE)
            if (value > MAX_AMOUNT) throw BadRequestException(AMOUNT_TOO_LARGE_MESSAGE)
            return value.toLong()
        }
    }
}
