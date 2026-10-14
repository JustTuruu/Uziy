package mn.uziy.backend.otp;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ResetPasswordReq(
        @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @Pattern(regexp = "\\d{6}", message = CODE) String code,
        @NotNull(message = PASSWORD_LENGTH) @Size(min = 6, max = 100, message = PASSWORD_LENGTH) String newPassword) {
}
