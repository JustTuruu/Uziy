package mn.uziy.backend.auth;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;
import mn.uziy.backend.domain.Gender;
import org.jspecify.annotations.Nullable;

public record RegisterViewerReq(
        @Pattern(regexp = "\\d{8}") String phoneNumber,
        @Size(min = 6, max = 100) String password,
        Gender gender,
        LocalDate birthDate,
        @Size(max = 50) String city,
        @Size(max = 50) @Nullable String district,
        @NotNull UUID verificationId) {

    /** Convenience for callers that omit the optional district. */
    public RegisterViewerReq(String phoneNumber, String password, Gender gender,
                             LocalDate birthDate, String city, UUID verificationId) {
        this(phoneNumber, password, gender, birthDate, city, null, verificationId);
    }
}
