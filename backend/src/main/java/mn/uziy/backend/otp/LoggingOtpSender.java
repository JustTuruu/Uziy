package mn.uziy.backend.otp;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Pattern: Strategy — development sender: nothing is sent, the code is written
 * to the log so a developer can type it into the app. Active unless
 * {@code uziy.otp.sender} names another channel; a real sender must never be
 * left off in production, or nobody can register.
 */
@Component
@ConditionalOnProperty(prefix = "uziy.otp", name = "sender", havingValue = "logging", matchIfMissing = true)
public class LoggingOtpSender implements OtpSender {

    private static final Logger LOG = LoggerFactory.getLogger(LoggingOtpSender.class);

    @Override
    public void send(String phoneNumber, String code, OtpPurpose purpose) {
        LOG.info("otp (not sent, dev) purpose={} phone={} code={}", purpose, phoneNumber, code);
    }
}
