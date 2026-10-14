package mn.uziy.backend.passwordreset;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.UUID;

/** A new password for the viewer who proved {@code phoneNumber} with the phone check {@code verificationId}. */
public record ResetPasswordReq(
        @NotNull(message = PHONE) @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotNull(message = PHONE_NOT_VERIFIED) UUID verificationId,
        @NotNull(message = PASSWORD_LENGTH) @Size(min = 6, max = 100, message = PASSWORD_LENGTH) String newPassword) {
}
