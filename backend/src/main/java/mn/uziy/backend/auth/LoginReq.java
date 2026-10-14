package mn.uziy.backend.auth;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record LoginReq(
        @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotBlank(message = PASSWORD_REQUIRED) String password) {
}
