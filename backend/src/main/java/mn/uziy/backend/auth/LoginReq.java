package mn.uziy.backend.auth;

import static mn.uziy.backend.common.FieldMessages.*;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import org.jspecify.annotations.Nullable;

/**
 * {@code deviceToken} is the secret a console panel received from {@code POST /auth/login/verify}; with it a
 * remembered browser skips the SMS step. It is not validated on purpose: a missing, stale or garbage value just
 * means "unknown browser", so the answer never tells which it was. Viewers' logins ignore it.
 */
public record LoginReq(
        @NotNull(message = PHONE) @Pattern(regexp = "\\d{8}", message = PHONE) String phoneNumber,
        @NotBlank(message = PASSWORD_REQUIRED) String password,
        @Nullable String deviceToken) {

    /** A login from a browser that has no device token (the app, or a console browser seen for the first time). */
    public LoginReq(String phoneNumber, String password) {
        this(phoneNumber, password, null);
    }

    /** Never print the password or the device secret. */
    @Override
    public String toString() {
        return "LoginReq[phoneNumber=" + phoneNumber + "]";
    }
}
