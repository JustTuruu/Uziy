package mn.uziy.backend.settings

import mn.uziy.backend.common.BadRequestException
import mn.uziy.backend.domain.PlatformSettingsRepository
import mn.uziy.backend.domain.current
import mn.uziy.backend.pricing.CampaignPricing
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime

interface PlatformSettingsService {
    fun get(): PlatformSettingsDto

    /**
     * Only affects campaigns created from now on — existing campaigns keep
     * the reward/cost (and commission snapshot) they were priced with.
     */
    fun update(req: UpdatePlatformSettingsReq, adminId: Long): PlatformSettingsDto
}

@Service
class PlatformSettingsServiceImpl(
    private val repo: PlatformSettingsRepository,
) : PlatformSettingsService {

    override fun get(): PlatformSettingsDto = PlatformSettingsDto.of(repo.current())

    @Transactional
    override fun update(req: UpdatePlatformSettingsReq, adminId: Long): PlatformSettingsDto {
        val commission = req.commissionPercent
        if (commission == null ||
            commission !in CampaignPricing.MIN_COMMISSION_PERCENT..CampaignPricing.MAX_COMMISSION_PERCENT
        ) throw BadRequestException(COMMISSION_RANGE_MESSAGE)

        val minReward = req.minRewardPerViewer
        if (minReward == null || minReward < 1) throw BadRequestException(MIN_REWARD_MESSAGE)

        val e = repo.current().apply {
            commissionPercent  = commission
            minRewardPerViewer = minReward
            updatedAt          = OffsetDateTime.now()
            updatedBy          = adminId
        }
        return PlatformSettingsDto.of(repo.save(e))
    }

    companion object {
        const val COMMISSION_RANGE_MESSAGE = "Платформын шимтгэл 1–90% хооронд байх ёстой"
        const val MIN_REWARD_MESSAGE = "Нэг үзэгчид олгох хамгийн бага урамшуулал 1 ₮-өөс багагүй байх ёстой"
    }
}
