package mn.uziy.backend.phoneverify;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import org.jspecify.annotations.Nullable;

/** {@code purpose} may be left out by apps that only register; it then means {@code REGISTER}. */
public record StartPhoneVerificationReq(
        @NotNull(message = PHONE) @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @Nullable PhoneVerificationPurpose purpose) {

    public PhoneVerificationPurpose purposeOrDefault() {
        return purpose == null ? PhoneVerificationPurpose.REGISTER : purpose;
    }
}
