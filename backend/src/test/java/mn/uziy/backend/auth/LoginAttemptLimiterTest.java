package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import mn.uziy.backend.common.TooManyRequestsException;
import org.junit.jupiter.api.Test;

class LoginAttemptLimiterTest {

    private static final String PHONE = "88112233";

    /** A clock the test can move. */
    private static final class MovableClock extends Clock {
        private Instant now = Instant.parse("2026-10-07T00:00:00Z");

        void advance(Duration d) {
            now = now.plus(d);
        }

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    private final MovableClock clock = new MovableClock();
    private final LoginAttemptLimiter limiter = new LoginAttemptLimiter(clock);

    private void failTimes(String phone, int n) {
        for (int i = 0; i < n; i++) {
            limiter.requireNotLocked(phone);
            limiter.recordFailure(phone);
        }
    }

    @Test
    void aFewMistakesDoNotLock() {
        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES - 1);

        assertThatCode(() -> limiter.requireNotLocked(PHONE)).doesNotThrowAnyException();
    }

    @Test
    void theFifthWrongPasswordLocksTheNumber() {
        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES);

        assertThatThrownBy(() -> limiter.requireNotLocked(PHONE))
                .isInstanceOf(TooManyRequestsException.class).hasMessage(LoginAttemptLimiter.LOCKED);
    }

    @Test
    void theLockIsPerNumber() {
        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES);

        assertThatCode(() -> limiter.requireNotLocked("99001122")).doesNotThrowAnyException();
    }

    @Test
    void theLockEndsAfterTheLockPeriod() {
        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES);

        clock.advance(LoginAttemptLimiter.LOCK.plusSeconds(1));

        assertThatCode(() -> limiter.requireNotLocked(PHONE)).doesNotThrowAnyException();
    }

    @Test
    void afterTheLockEndsTheCountStartsFromZeroAgain() {
        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES);
        clock.advance(LoginAttemptLimiter.LOCK.plusSeconds(1));

        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES - 1);

        assertThatCode(() -> limiter.requireNotLocked(PHONE)).doesNotThrowAnyException();
    }

    @Test
    void aSuccessfulLoginClearsTheCount() {
        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES - 1);
        limiter.recordSuccess(PHONE);

        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES - 1);

        assertThatCode(() -> limiter.requireNotLocked(PHONE)).doesNotThrowAnyException();
    }

    @Test
    void mistakesSpreadOverMoreThanTheLockPeriodDoNotAddUp() {
        failTimes(PHONE, LoginAttemptLimiter.MAX_FAILURES - 1);
        clock.advance(LoginAttemptLimiter.LOCK.plusMinutes(1));

        failTimes(PHONE, 1);

        assertThatCode(() -> limiter.requireNotLocked(PHONE)).doesNotThrowAnyException();
    }
}
