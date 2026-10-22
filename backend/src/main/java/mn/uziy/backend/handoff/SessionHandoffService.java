package mn.uziy.backend.handoff;

import mn.uziy.backend.auth.AuthResponse;
import org.jspecify.annotations.Nullable;

/**
 * Moves a signed-in admin from the company login page to the admin panel (two origins, two storages) without
 * putting a token in a URL.
 */
public interface SessionHandoffService {

    /** A fresh one-time code for {@code adminId}. */
    HandoffCode create(long adminId);

    /**
     * Spends {@code code} and signs its admin in.
     *
     * @throws mn.uziy.backend.common.BadRequestException for an unknown, spent or expired code, or one whose
     *         account is no longer an admin — always the same words
     */
    AuthResponse redeem(@Nullable String code);
}
