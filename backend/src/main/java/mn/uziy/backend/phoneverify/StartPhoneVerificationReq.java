package mn.uziy.backend.phoneverify;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record StartPhoneVerificationReq(@NotNull(message = PHONE) @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber) {
}
