package mn.uziy.backend.account;

import static mn.uziy.backend.common.FieldMessages.PASSWORD_REQUIRED;
import static mn.uziy.backend.common.FieldMessages.PASSWORD_TOO_LONG;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** The viewer's current password, asked again so a phone left unlocked cannot delete the account. */
public record DeleteAccountReq(
        @NotBlank(message = PASSWORD_REQUIRED) @Size(max = DeleteAccountReq.PASSWORD_MAX, message = PASSWORD_TOO_LONG)
        String password) {

    /** Same upper bound as at registration. */
    public static final int PASSWORD_MAX = 100;
}
