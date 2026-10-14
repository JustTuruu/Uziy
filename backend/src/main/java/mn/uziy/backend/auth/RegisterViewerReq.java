package mn.uziy.backend.auth;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;
import mn.uziy.backend.domain.Gender;
import org.jspecify.annotations.Nullable;

public record RegisterViewerReq(
        @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotNull(message = PASSWORD_LENGTH) @Size(min = 6, max = 100, message = PASSWORD_LENGTH) String password,
        @NotNull(message = GENDER_REQUIRED) Gender gender,
        @NotNull(message = BIRTH_DATE_REQUIRED) LocalDate birthDate,
        @NotBlank(message = CITY_REQUIRED) @Size(max = 50, message = CITY_TOO_LONG) String city,
        @Size(max = 50, message = DISTRICT_TOO_LONG) @Nullable String district,
        @NotNull(message = PHONE_NOT_VERIFIED) UUID verificationId) {

    /** Convenience for callers that omit the optional district. */
    public RegisterViewerReq(String phoneNumber, String password, Gender gender,
                             LocalDate birthDate, String city, UUID verificationId) {
        this(phoneNumber, password, gender, birthDate, city, null, verificationId);
    }
}
