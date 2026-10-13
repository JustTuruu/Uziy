package mn.uziy.backend.phoneverify;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Pattern: Strategy — development stand-in for verify.mn. Nothing is texted, and like the real provider a
 * session stays PENDING until "the SMS arrives" — here when a developer calls {@link #receiveSms} (through
 * {@link SimulatedSmsController}; the ready-made curl command is logged). It never verifies on its own, so the
 * app cannot register a phone nobody confirmed. Sessions live in memory: after a restart they are EXPIRED.
 * Production refuses to boot with it ({@code ProductionReadinessCheck}).
 */
@Component
@ConditionalOnProperty(prefix = "uziy.phone-verification", name = "provider", havingValue = "simulated",
        matchIfMissing = true)
public class SimulatedPhoneVerificationGateway implements PhoneVerificationGateway {

    private static final Logger LOG = LoggerFactory.getLogger(SimulatedPhoneVerificationGateway.class);

    static final String SHORTCODE = "144773";
    static final Duration TTL = Duration.ofMinutes(5);

    private final Clock clock;
    /** sessionId → whether its SMS has "arrived". */
    private final Map<String, Boolean> smsReceived = new ConcurrentHashMap<>();

    public SimulatedPhoneVerificationGateway(Clock clock) {
        this.clock = clock;
    }

    @Override
    public PhoneVerificationSession start(String phoneNumber, String text) {
        String sessionId = "simulated-" + UUID.randomUUID();
        smsReceived.put(sessionId, false);
        LOG.info("phone verification (simulated, nothing sent) phone={} text={} — to pretend the SMS arrived: "
                        + "curl -X POST http://localhost:8080{}",
                phoneNumber, text, SimulatedSmsController.PATH.replace("{sessionId}", sessionId));
        return new PhoneVerificationSession(
                sessionId,
                SHORTCODE,
                text,
                "sms:" + SHORTCODE + "?body=" + text,
                "Та өөрийн " + phoneNumber + " дугаараас " + SHORTCODE + " дугаарт \"" + text
                        + "\" гэж SMS илгээнэ үү. (Туршилтын горим: SMS ирсэн гэж backend-ийн log дээрх curl-ээр заана.)",
                OffsetDateTime.now(clock).plus(TTL));
    }

    @Override
    public PhoneVerificationStatus status(String sessionId) {
        Boolean received = smsReceived.get(sessionId);
        if (received == null) {
            return PhoneVerificationStatus.EXPIRED;
        }
        return received ? PhoneVerificationStatus.VERIFIED : PhoneVerificationStatus.PENDING;
    }

    /** Pretends the user's SMS for {@code sessionId} arrived; false for a session this instance never opened. */
    public boolean receiveSms(String sessionId) {
        return smsReceived.replace(sessionId, true) != null;
    }
}
