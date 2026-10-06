package mn.uziy.backend.company;

import mn.uziy.backend.domain.CampaignEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — the one place a campaign entity becomes its response record. */
@Component
public class CampaignMapper {

    public CampaignDto toDto(CampaignEntity c) {
        return new CampaignDto(
                c.getId(), c.getTitle(), c.getVideoUrl(),
                c.getDurationSeconds(),
                c.hasVideo(),
                c.getTargetGender(),
                c.getMinAge(), c.getMaxAge(), c.getTargetCity(),
                c.getTotalBudget(), c.getRemainingBudget(),
                c.getCostPerView(), c.getRewardPerUser(),
                c.getStatus(), c.getCreatedAt(),
                c.getTargetViewers(),
                c.getCommissionPercent(),
                c.getPaidAt());
    }
}
