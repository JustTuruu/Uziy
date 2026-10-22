package mn.uziy.backend.admin;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import mn.uziy.backend.common.BcryptSafe;

/**
 * An admin opening another admin's account; {@code password} is the temporary one handed over. The new admin still
 * has to prove {@code phoneNumber} by SMS at every login, so the phone must be one they hold.
 */
public record CreateAdminReq(
        @NotNull(message = PHONE) @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotNull(message = PASSWORD_LENGTH) @Size(min = 6, max = 100, message = PASSWORD_LENGTH) @BcryptSafe
        String password) {
}
