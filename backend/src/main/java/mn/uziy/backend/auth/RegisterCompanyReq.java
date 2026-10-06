package mn.uziy.backend.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterCompanyReq(
        @Pattern(regexp = "\\d{8}") String phoneNumber,
        @Size(min = 6, max = 100) String password,
        @NotBlank @Size(max = 120) String companyName) {
}
