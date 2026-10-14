package mn.uziy.backend.company;

import java.util.Set;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.media.CampaignImageService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * The cover is part of what the admin approves, so a company may change it only until then: while the survey
 * waits for payment or for moderation. After approval only an admin can change it (CampaignImageController).
 * Storage and image checks are CampaignImageService's.
 */
@Service
public class CompanyCampaignImageServiceImpl implements CompanyCampaignImageService {

    static final Set<CampaignStatus> EDITABLE = Set.of(CampaignStatus.AWAITING_PAYMENT, CampaignStatus.PENDING);
    static final String LOCKED = "Батлагдсан судалгааны зургийг өөрчлөх боломжгүй";

    private final CampaignRepository campaigns;
    private final CampaignImageService images;

    public CompanyCampaignImageServiceImpl(CampaignRepository campaigns, CampaignImageService images) {
        this.campaigns = campaigns;
        this.images = images;
    }

    @Override
    @Transactional
    public String upload(long companyId, long campaignId, MultipartFile file) {
        requireEditable(companyId, campaignId);
        return images.upload(campaignId, file);
    }

    @Override
    @Transactional
    public void remove(long companyId, long campaignId) {
        requireEditable(companyId, campaignId);
        images.remove(campaignId);
    }

    private void requireEditable(long companyId, long campaignId) {
        CampaignEntity campaign = OwnedCampaigns.owned(campaigns, companyId, campaignId);
        if (!EDITABLE.contains(campaign.getStatus())) {
            throw new ConflictException(LOCKED);
        }
    }
}
