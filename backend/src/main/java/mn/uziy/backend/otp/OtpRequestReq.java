package mn.uziy.backend.otp;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record OtpRequestReq(@Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber, @NotNull OtpPurpose purpose) {
}
