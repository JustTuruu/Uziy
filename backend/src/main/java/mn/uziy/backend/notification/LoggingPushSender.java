package mn.uziy.backend.notification;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** Pattern: Strategy — default sender (push disabled): logs what would be sent. */
@Component
@ConditionalOnProperty(prefix = "uziy.push", name = "enabled", havingValue = "false", matchIfMissing = true)
public class LoggingPushSender implements PushSender {

    private static final Logger LOG = LoggerFactory.getLogger(LoggingPushSender.class);
    private static final String TYPE_KEY = "type";

    @Override
    public PushResult send(PushMessage message, List<String> tokens) {
        // Only the kind and the count: the title/body carry amounts, bank names and reject reasons, which are a
        // viewer's personal data and do not belong in the server log (audit 2026-10-22).
        LOG.info("push (disabled, not sent) type={} recipients={}", message.data().get(TYPE_KEY), tokens.size());
        return PushResult.none();
    }
}
