package mn.uziy.backend.handoff;

import java.time.OffsetDateTime;

/** A one-time code that signs its admin into the admin panel once, until {@code expiresAt}. */
public record HandoffCode(String code, OffsetDateTime expiresAt) {
}
