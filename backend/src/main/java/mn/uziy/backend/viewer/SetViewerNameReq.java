package mn.uziy.backend.viewer;

import static mn.uziy.backend.auth.RegisterViewerReq.NAME_MAX;
import static mn.uziy.backend.auth.RegisterViewerReq.NAME_PATTERN;
import static mn.uziy.backend.common.FieldMessages.FIRST_NAME_REQUIRED;
import static mn.uziy.backend.common.FieldMessages.LAST_NAME_REQUIRED;
import static mn.uziy.backend.common.FieldMessages.NAME_LETTERS;
import static mn.uziy.backend.common.FieldMessages.NAME_TOO_LONG;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Овог + нэр for an account that has none yet; the same rules as at registration. */
public record SetViewerNameReq(
        @NotBlank(message = LAST_NAME_REQUIRED) @Size(max = NAME_MAX, message = NAME_TOO_LONG)
        @Pattern(regexp = NAME_PATTERN, message = NAME_LETTERS) String lastName,
        @NotBlank(message = FIRST_NAME_REQUIRED) @Size(max = NAME_MAX, message = NAME_TOO_LONG)
        @Pattern(regexp = NAME_PATTERN, message = NAME_LETTERS) String firstName) {
}
