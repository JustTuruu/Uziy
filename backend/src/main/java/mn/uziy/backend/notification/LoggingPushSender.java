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

    @Override
    public PushResult send(PushMessage message, List<String> tokens) {
        LOG.info("push (disabled, not sent) title='{}' body='{}' data={} recipients={}",
                message.title(), message.body(), message.data(), tokens.size());
        return PushResult.none();
    }
}
