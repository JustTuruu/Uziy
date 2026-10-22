package mn.uziy.backend.auth;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;
import mn.uziy.backend.common.BcryptSafe;
import mn.uziy.backend.domain.Gender;
import org.jspecify.annotations.Nullable;

public record RegisterViewerReq(
        @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotNull(message = PASSWORD_LENGTH) @Size(min = 6, max = 100, message = PASSWORD_LENGTH) @BcryptSafe String password,
        @NotBlank(message = LAST_NAME_REQUIRED) @Size(max = NAME_MAX, message = NAME_TOO_LONG)
        @Pattern(regexp = NAME_PATTERN, message = NAME_LETTERS) String lastName,
        @NotBlank(message = FIRST_NAME_REQUIRED) @Size(max = NAME_MAX, message = NAME_TOO_LONG)
        @Pattern(regexp = NAME_PATTERN, message = NAME_LETTERS) String firstName,
        @NotNull(message = GENDER_REQUIRED) Gender gender,
        @NotNull(message = BIRTH_DATE_REQUIRED) LocalDate birthDate,
        @NotBlank(message = CITY_REQUIRED) @Size(max = 50, message = CITY_TOO_LONG) String city,
        @Size(max = 50, message = DISTRICT_TOO_LONG) @Nullable String district,
        @NotNull(message = PHONE_NOT_VERIFIED) UUID verificationId) {

    /**
     * A personal name: letters of any alphabet, with the spaces, hyphens and apostrophes double names use
     * ("Оюун-Эрдэнэ"). Starts with a letter; surrounding spaces are trimmed when saved.
     */
    public static final String NAME_PATTERN = "^\\s*\\p{L}[\\p{L} '\\-]*\\s*$";

    /** Matches the {@code users.last_name} / {@code first_name} columns. */
    public static final int NAME_MAX = 60;

    /** Convenience for callers that omit the optional district. */
    public RegisterViewerReq(String phoneNumber, String password, String lastName, String firstName,
                             Gender gender, LocalDate birthDate, String city, UUID verificationId) {
        this(phoneNumber, password, lastName, firstName, gender, birthDate, city, null, verificationId);
    }
}
