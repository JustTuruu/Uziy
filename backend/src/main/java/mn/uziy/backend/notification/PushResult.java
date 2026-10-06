package mn.uziy.backend.notification;

import java.util.List;

/** Outcome of a send: tokens the provider says are dead and should be deleted. */
public record PushResult(List<String> invalidTokens) {
    public PushResult {
        invalidTokens = List.copyOf(invalidTokens);
    }

    public static PushResult none() {
        return new PushResult(List.of());
    }
}
