package mn.uziy.backend.company;

import mn.uziy.backend.domain.CampaignPaymentEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — the one place a payment entity becomes its response record. */
@Component
public class PaymentMapper {

    public PaymentDto toDto(CampaignPaymentEntity p, String campaignTitle) {
        return new PaymentDto(
                p.getId(), p.getCampaignId(), campaignTitle,
                p.getAmount(), p.getProvider(), p.getStatus(),
                p.getReference(), p.getCreatedAt(), p.getPaidAt());
    }
}
