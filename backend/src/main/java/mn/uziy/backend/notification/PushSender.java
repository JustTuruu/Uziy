package mn.uziy.backend.notification;

import java.util.List;

/**
 * Pattern: Strategy — how a push reaches devices (FCM, or just a log line). Implementations
 * must never throw: a delivery problem is logged and reported only through
 * {@link PushResult#invalidTokens()}.
 */
public interface PushSender {

    PushResult send(PushMessage message, List<String> tokens);
}
