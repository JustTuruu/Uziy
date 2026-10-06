package mn.uziy.backend.payout;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;

public record CreatePayoutReq(
        @Positive double amount,
        @NotBlank String bank,
        @NotBlank String accountNumber,
        @NotBlank String accountName,
        @NotBlank String nationalId) {
}
