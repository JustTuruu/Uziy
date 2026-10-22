package mn.uziy.backend.handoff;

import org.jspecify.annotations.Nullable;

/** The admin panel spending the code it received in its URL fragment. */
public record RedeemHandoffReq(@Nullable String code) {
}
