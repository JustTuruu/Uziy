package mn.uziy.backend.company;

import mn.uziy.backend.common.ForbiddenException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;

/** Loads a campaign and enforces that the caller is the company that owns it. */
final class OwnedCampaigns {

    static final String NOT_YOURS = "Энэ судалгаа танай компанийнх биш байна";

    private OwnedCampaigns() {
    }

    static CampaignEntity owned(CampaignRepository campaigns, long companyId, long campaignId) {
        CampaignEntity c = campaigns.findById(campaignId).orElseThrow(() -> new NotFoundException(Messages.CAMPAIGN_NOT_FOUND));
        if (c.getCompanyId() != companyId) {
            throw new ForbiddenException(NOT_YOURS);
        }
        return c;
    }
}
