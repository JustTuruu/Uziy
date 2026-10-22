package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
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

    // ------- bounded memory (2026-10-22 audit: the table could be grown without limit) ------------------

    @Test
    void theTableNeverHoldsMoreThanItsCapNoMatterHowManyPhonesAreTried() {
        LoginAttemptLimiter small = new LoginAttemptLimiter(clock, 3);

        for (int i = 0; i < 1_000; i++) {
            small.recordFailure("9" + i);
        }

        assertThat(small.tracked()).isEqualTo(3);
    }

    @Test
    void whenFullThePhoneWhoseLastMistakeIsOldestIsForgottenFirst() {
        LoginAttemptLimiter small = new LoginAttemptLimiter(clock, 2);
        for (int i = 0; i < LoginAttemptLimiter.MAX_FAILURES; i++) {
            small.recordFailure("A");
        }
        clock.advance(Duration.ofSeconds(1));
        for (int i = 0; i < LoginAttemptLimiter.MAX_FAILURES; i++) {
            small.recordFailure("B");
        }
        clock.advance(Duration.ofSeconds(1));

        small.recordFailure("C");

        assertThatCode(() -> small.requireNotLocked("A")).doesNotThrowAnyException();
        assertThatThrownBy(() -> small.requireNotLocked("B")).isInstanceOf(TooManyRequestsException.class);
    }

    @Test
    void aNewMistakeMovesAPhoneToTheBackOfTheEvictionQueue() {
        LoginAttemptLimiter small = new LoginAttemptLimiter(clock, 2);
        for (int i = 0; i < LoginAttemptLimiter.MAX_FAILURES - 1; i++) {
            small.recordFailure("A");
        }
        small.recordFailure("B");
        clock.advance(Duration.ofSeconds(1));
        small.recordFailure("A"); // A is now the most recent, and locked

        small.recordFailure("C"); // evicts B, not A

        assertThatThrownBy(() -> small.requireNotLocked("A")).isInstanceOf(TooManyRequestsException.class);
    }

    @Test
    void phonesWhoseLockRanOutAreDroppedWithoutAnyoneAskingAboutThem() {
        for (int i = 0; i < 100; i++) {
            limiter.recordFailure("9" + i);
        }
        clock.advance(LoginAttemptLimiter.LOCK.plusSeconds(1));

        limiter.recordFailure(PHONE);

        assertThat(limiter.tracked()).isEqualTo(1);
    }

    @Test
    void parallelWrongPasswordsAreAllCounted() throws Exception {
        int threads = LoginAttemptLimiter.MAX_FAILURES;
        java.util.concurrent.ExecutorService pool = java.util.concurrent.Executors.newFixedThreadPool(threads);
        java.util.concurrent.CountDownLatch start = new java.util.concurrent.CountDownLatch(1);
        java.util.List<java.util.concurrent.Future<?>> done = new java.util.ArrayList<>();
        for (int i = 0; i < threads; i++) {
            done.add(pool.submit(() -> {
                start.await();
                limiter.recordFailure(PHONE);
                return null;
            }));
        }
        start.countDown();
        for (java.util.concurrent.Future<?> f : done) {
            f.get();
        }
        pool.shutdown();

        assertThatThrownBy(() -> limiter.requireNotLocked(PHONE)).isInstanceOf(TooManyRequestsException.class);
    }

    @Test
    void aCapBelowOneIsAProgrammingError() {
        assertThatThrownBy(() -> new LoginAttemptLimiter(clock, 0)).isInstanceOf(IllegalArgumentException.class);
    }
}
