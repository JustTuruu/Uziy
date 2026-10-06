package mn.uziy.backend.company;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.PaymentProvider;
import mn.uziy.backend.domain.PaymentStatus;
import org.jspecify.annotations.Nullable;

public record PaymentDto(
        long id,
        long campaignId,
        String campaignTitle,
        double amount,
        PaymentProvider provider,
        PaymentStatus status,
        String reference,
        OffsetDateTime createdAt,
        @Nullable OffsetDateTime paidAt) {

    public static PaymentDto of(CampaignPaymentEntity p, String campaignTitle) {
        return new PaymentDto(
                p.getId(), p.getCampaignId(), campaignTitle,
                p.getAmount(), p.getProvider(), p.getStatus(),
                p.getReference(), p.getCreatedAt(), p.getPaidAt());
    }
}
