package mn.uziy.backend.company;

import java.util.List;

/** Paying for campaigns, and the company's payment history. */
public interface CampaignPaymentService {

    /**
     * Pay for one campaign (AWAITING_PAYMENT → PENDING, i.e. into the admin
     * moderation queue) through whichever {@code PaymentGateway} is available.
     *
     * <p>Race safety: the status flip is a conditional UPDATE (0 rows → conflict),
     * and the partial unique index ux_campaign_payments_one_paid backs it up.
     */
    PayCampaignResponse pay(long companyId, long campaignId);

    /** The company's campaign payments, newest first. */
    List<PaymentDto> list(long companyId);
}
