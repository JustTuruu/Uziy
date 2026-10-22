package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import mn.uziy.backend.domain.AccountState;
import mn.uziy.backend.domain.Role;
import org.junit.jupiter.api.Test;

class JwtAuthFilterTest {

    private static final JwtPrincipal VIEWER = new JwtPrincipal(7L, Role.VIEWER);
    private static final OffsetDateTime RESET = OffsetDateTime.of(2026, 10, 22, 9, 0, 0, 500_000_000, ZoneOffset.UTC);

    @Test
    void aTokenOfAnAccountThatNeverChangedItsPasswordIsValid() {
        assertThat(JwtAuthFilter.stillValid(new AccountState(Role.VIEWER, null), VIEWER,
                Instant.parse("2026-01-01T00:00:00Z"))).isTrue();
    }

    @Test
    void aRoleChangedSinceTheTokenWasIssuedMakesItInvalid() {
        assertThat(JwtAuthFilter.stillValid(new AccountState(Role.COMPANY, null), VIEWER,
                Instant.parse("2026-01-01T00:00:00Z"))).isFalse();
    }

    @Test
    void aTokenIssuedBeforeThePasswordChangeIsInvalid() {
        assertThat(JwtAuthFilter.stillValid(new AccountState(Role.VIEWER, RESET), VIEWER,
                Instant.parse("2026-10-22T08:59:59Z"))).isFalse();
    }

    /** JWT stores whole seconds: the login right after a reset (same second) must keep working. */
    @Test
    void aTokenIssuedInTheSameSecondOrLaterIsValid() {
        AccountState state = new AccountState(Role.VIEWER, RESET);
        assertThat(JwtAuthFilter.stillValid(state, VIEWER, Instant.parse("2026-10-22T09:00:00Z"))).isTrue();
        assertThat(JwtAuthFilter.stillValid(state, VIEWER, Instant.parse("2026-10-22T09:30:00Z"))).isTrue();
    }
}
