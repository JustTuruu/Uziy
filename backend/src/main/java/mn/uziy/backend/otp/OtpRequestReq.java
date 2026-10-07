package mn.uziy.backend.otp;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record OtpRequestReq(@Pattern(regexp = "\\d{8}") String phoneNumber, @NotNull OtpPurpose purpose) {
}
