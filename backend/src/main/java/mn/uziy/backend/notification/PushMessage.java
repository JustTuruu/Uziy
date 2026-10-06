package mn.uziy.backend.notification;

import java.util.Map;

/** Provider-neutral notification: visible title/body plus a string-only data payload. */
public record PushMessage(String title, String body, Map<String, String> data) {
    public PushMessage {
        data = Map.copyOf(data);
    }
}
