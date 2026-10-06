package mn.uziy.backend.company;

import java.util.List;
import mn.uziy.backend.domain.CampaignStatus;

/** A company's campaigns: create, read and drive through the lifecycle. */
public interface CampaignService {

    List<CampaignDto> list(long companyId);

    CampaignDto get(long companyId, long campaignId);

    /**
     * Creates the campaign in AWAITING_PAYMENT. Pricing is recomputed here
     * from the CURRENT platform settings — the wizard's preview is advisory,
     * the numbers saved (and later charged) are the server's.
     */
    CampaignDto create(long companyId, CreateCampaignReq req);

    /**
     * Company-driven lifecycle: ACTIVE ⇄ PAUSED, ACTIVE|PAUSED → COMPLETED.
     * Everything else (notably PENDING → ACTIVE, which would skip moderation,
     * and anything out of AWAITING_PAYMENT, which would skip payment) is a conflict.
     */
    CampaignDto setStatus(long companyId, long campaignId, CampaignStatus status);
}
