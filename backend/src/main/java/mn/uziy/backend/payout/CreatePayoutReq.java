package mn.uziy.backend.payout;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;

public record CreatePayoutReq(
        @Positive(message = PAYOUT_AMOUNT) double amount,
        @NotBlank(message = BANK_REQUIRED) String bank,
        @NotBlank(message = ACCOUNT_NUMBER_REQUIRED) String accountNumber,
        @NotBlank(message = ACCOUNT_NAME_REQUIRED) String accountName) {
}
