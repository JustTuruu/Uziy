package mn.uziy.backend.auth;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterCompanyReq(
        @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotNull(message = PASSWORD_LENGTH) @Size(min = 6, max = 100, message = PASSWORD_LENGTH) String password,
        @NotBlank(message = COMPANY_NAME_REQUIRED) @Size(max = 120, message = COMPANY_NAME_TOO_LONG) String companyName) {
}
