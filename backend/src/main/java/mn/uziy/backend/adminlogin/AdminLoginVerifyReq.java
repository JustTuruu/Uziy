package mn.uziy.backend.adminlogin;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.util.UUID;

public record AdminLoginVerifyReq(
        @NotNull(message = PHONE) @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotNull(message = PHONE_NOT_VERIFIED) UUID verificationId) {
}
