package mn.uziy.backend.auth;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import mn.uziy.backend.domain.Gender;
import org.jspecify.annotations.Nullable;

public record RegisterViewerReq(
        @Pattern(regexp = "\\d{8}") String phoneNumber,
        @Size(min = 6, max = 100) String password,
        Gender gender,
        LocalDate birthDate,
        @Size(max = 50) String city,
        @Size(max = 50) @Nullable String district,
        @Pattern(regexp = "\\d{6}") String otpCode) {

    /** Convenience for callers that omit the optional district. */
    public RegisterViewerReq(String phoneNumber, String password, Gender gender,
                             LocalDate birthDate, String city, String otpCode) {
        this(phoneNumber, password, gender, birthDate, city, null, otpCode);
    }
}
