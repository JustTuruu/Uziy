package mn.uziy.backend.company;

import java.time.OffsetDateTime;
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
}
