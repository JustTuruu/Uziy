package mn.uziy.backend.admin;

import mn.uziy.backend.company.CampaignDto;
import mn.uziy.backend.company.CampaignMapper;
import mn.uziy.backend.domain.CampaignEntity;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — builds the admin campaign shapes from entities. */
@Component
public class AdminCampaignMapper {

    private final CampaignMapper campaignMapper;

    public AdminCampaignMapper(CampaignMapper campaignMapper) {
        this.campaignMapper = campaignMapper;
    }

    public CampaignDto toDto(CampaignEntity c) {
        return campaignMapper.toDto(c);
    }

    public CampaignDetailDto toDetail(CampaignEntity c, @Nullable String companyName, long completedViews) {
        return new CampaignDetailDto(
                toDto(c),
                c.getCompanyId(),
                companyName,
                completedViews,
                c.getTotalBudget() - c.getRemainingBudget());
    }
}
