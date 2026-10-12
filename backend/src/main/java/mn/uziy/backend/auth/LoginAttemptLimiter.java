package mn.uziy.backend.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import mn.uziy.backend.common.TooManyRequestsException;
import org.springframework.stereotype.Component;

/**
 * Slows password guessing: after {@value #MAX_FAILURES} wrong passwords for one phone number the account is
 * locked for {@link #LOCK}, and during the lock even the right password is refused — otherwise a guesser would
 * just keep going until one lands. A success clears the count. The same applies to a phone number that has no
 * account, so the lock itself does not reveal who is registered.
 *
 * <p>Held in memory: it resets on restart and is per server instance. Behind several instances put the same
 * rule in a shared store (Redis) or at the gateway; this is the floor, not the ceiling.
 */
@Component
public class LoginAttemptLimiter {

    public static final int MAX_FAILURES = 5;
    public static final Duration LOCK = Duration.ofMinutes(15);
    public static final String LOCKED = "Хэт олон удаа буруу оролдлоо. 15 минутын дараа дахин оролдоно уу";

    /** Past this many tracked phones, entries whose lock has run out are swept away. */
    private static final int SWEEP_THRESHOLD = 10_000;

    private record Record(int failures, Instant lastFailure) {
    }

    private final Map<String, Record> attempts = new ConcurrentHashMap<>();
    private final Clock clock;

    public LoginAttemptLimiter(Clock clock) {
        this.clock = clock;
    }

    /** @throws TooManyRequestsException while {@code phone} is locked */
    public void requireNotLocked(String phone) {
        Record r = attempts.get(phone);
        if (r == null) {
            return;
        }
        Instant now = clock.instant();
        if (r.lastFailure().plus(LOCK).isBefore(now)) {
            attempts.remove(phone, r); // the lock ran out: start fresh
            return;
        }
        if (r.failures() >= MAX_FAILURES) {
            throw new TooManyRequestsException(LOCKED);
        }
    }

    public void recordFailure(String phone) {
        Instant now = clock.instant();
        attempts.merge(phone, new Record(1, now), (old, fresh) ->
                old.lastFailure().plus(LOCK).isBefore(now) ? fresh : new Record(old.failures() + 1, now));
        if (attempts.size() > SWEEP_THRESHOLD) {
            attempts.entrySet().removeIf(e -> e.getValue().lastFailure().plus(LOCK).isBefore(now));
        }
    }

    public void recordSuccess(String phone) {
        attempts.remove(phone);
    }
}
