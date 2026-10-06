package mn.uziy.backend.payout;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.PayoutStatus;
import org.jspecify.annotations.Nullable;

public record PayoutDto(
        long id,
        long userId,
        String userPhone,
        double amount,
        String bank,
        String accountNumber,
        String accountName,
        String nationalId,
        PayoutStatus status,
        boolean isFirstPayout,
        OffsetDateTime requestedAt,
        @Nullable OffsetDateTime decidedAt,
        @Nullable String rejectReason) {
}
