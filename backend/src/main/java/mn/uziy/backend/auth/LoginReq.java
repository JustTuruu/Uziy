package mn.uziy.backend.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record LoginReq(
        @Pattern(regexp = "\\d{8}", message = "8 digits") String phoneNumber,
        @NotBlank String password) {
}
