package mn.uziy.backend.otp;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ResetPasswordReq(
        @Pattern(regexp = "\\d{8}") String phoneNumber,
        @Pattern(regexp = "\\d{6}") String code,
        @Size(min = 6, max = 100) String newPassword) {
}
