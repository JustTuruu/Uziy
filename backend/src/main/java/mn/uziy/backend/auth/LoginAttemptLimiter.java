package mn.uziy.backend.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Iterator;
import java.util.LinkedHashMap;
import mn.uziy.backend.common.TooManyRequestsException;
import org.springframework.beans.factory.annotation.Autowired;
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

    /**
     * At most this many phones are remembered (a few MB). Each failure costs the caller a BCrypt check, so filling
     * the table means tens of thousands of requests inside one lock period; only then does the phone whose last
     * mistake is oldest drop out, and the gateway's per-IP limit (PRODUCTION_CHECKLIST) is the guard beyond that.
     */
    static final int DEFAULT_MAX_TRACKED = 50_000;

    private record Record(int failures, Instant lastFailure) {
        boolean expiredAt(Instant now) {
            return lastFailure.plus(LOCK).isBefore(now);
        }
    }

    /**
     * Ordered by last failure, oldest first (a phone is moved to the end on each failure), so both the expired
     * entries and the eviction candidate are always at the head: every operation is O(1) amortised, and nothing
     * ever scans the whole table. Guarded by {@code this}: the work under the lock is tiny next to the BCrypt
     * check every login already does.
     */
    private final LinkedHashMap<String, Record> attempts = new LinkedHashMap<>();
    private final Clock clock;
    private final int maxTracked;

    @Autowired
    public LoginAttemptLimiter(Clock clock) {
        this(clock, DEFAULT_MAX_TRACKED);
    }

    LoginAttemptLimiter(Clock clock, int maxTracked) {
        if (maxTracked < 1) {
            throw new IllegalArgumentException("maxTracked must be positive");
        }
        this.clock = clock;
        this.maxTracked = maxTracked;
    }

    /** @throws TooManyRequestsException while {@code phone} is locked */
    public synchronized void requireNotLocked(String phone) {
        Instant now = clock.instant();
        dropExpired(now);
        Record r = attempts.get(phone);
        if (r != null && r.failures() >= MAX_FAILURES) {
            throw new TooManyRequestsException(LOCKED);
        }
    }

    public synchronized void recordFailure(String phone) {
        Instant now = clock.instant();
        dropExpired(now);
        Record old = attempts.remove(phone);
        attempts.put(phone, new Record(old == null ? 1 : old.failures() + 1, now));
        while (attempts.size() > maxTracked) {
            Iterator<String> eldest = attempts.keySet().iterator();
            eldest.next();
            eldest.remove();
        }
    }

    public synchronized void recordSuccess(String phone) {
        attempts.remove(phone);
    }

    /** How many phones are remembered right now. */
    synchronized int tracked() {
        return attempts.size();
    }

    /** Pops the entries whose lock has run out; they sit at the head because the map is in failure order. */
    private void dropExpired(Instant now) {
        Iterator<Record> oldestFirst = attempts.values().iterator();
        while (oldestFirst.hasNext() && oldestFirst.next().expiredAt(now)) {
            oldestFirst.remove();
        }
    }
}
