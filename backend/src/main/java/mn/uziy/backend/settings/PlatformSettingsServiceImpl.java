package mn.uziy.backend.settings;

import java.time.OffsetDateTime;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.PlatformSettings;
import mn.uziy.backend.domain.PlatformSettingsEntity;
import mn.uziy.backend.domain.PlatformSettingsRepository;
import mn.uziy.backend.pricing.CampaignPricing;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlatformSettingsServiceImpl implements PlatformSettingsService {

    public static final String COMMISSION_RANGE_MESSAGE = "Платформын шимтгэл 1–90% хооронд байх ёстой";
    public static final String MIN_REWARD_MESSAGE =
            "Нэг үзэгчид олгох хамгийн бага урамшуулал 1 ₮-өөс багагүй байх ёстой";
    private static final int MIN_REWARD_FLOOR = 1;

    private final PlatformSettingsRepository repo;

    public PlatformSettingsServiceImpl(PlatformSettingsRepository repo) {
        this.repo = repo;
    }

    @Override
    public PlatformSettingsDto get() {
        return PlatformSettingsDto.of(PlatformSettings.current(repo));
    }

    @Override
    @Transactional
    public PlatformSettingsDto update(UpdatePlatformSettingsReq req, long adminId) {
        Integer commission = req.commissionPercent();
        if (commission == null
                || commission < CampaignPricing.MIN_COMMISSION_PERCENT
                || commission > CampaignPricing.MAX_COMMISSION_PERCENT) {
            throw new BadRequestException(COMMISSION_RANGE_MESSAGE);
        }

        Integer minReward = req.minRewardPerViewer();
        if (minReward == null || minReward < MIN_REWARD_FLOOR) {
            throw new BadRequestException(MIN_REWARD_MESSAGE);
        }

        PlatformSettingsEntity e = PlatformSettings.current(repo);
        e.setCommissionPercent(commission);
        e.setMinRewardPerViewer(minReward);
        e.setUpdatedAt(OffsetDateTime.now());
        e.setUpdatedBy(adminId);
        return PlatformSettingsDto.of(repo.save(e));
    }
}
