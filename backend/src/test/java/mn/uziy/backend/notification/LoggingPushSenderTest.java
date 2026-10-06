package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class LoggingPushSenderTest {

    @Test
    void neverReportsInvalidTokensAndDoesNotThrow() {
        PushResult r = new LoggingPushSender().send(new PushMessage("t", "b", Map.of()), List.of("a", "b"));

        assertThat(r.invalidTokens()).isEmpty();
    }
}
