package mn.uziy.backend.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class BcryptSafeTest {

    private final BcryptSafe.Validator validator = new BcryptSafe.Validator();

    @Test
    void countsBytesNotCharacters() {
        assertThat(validator.isValid("a".repeat(72), null)).isTrue();
        assertThat(validator.isValid("a".repeat(73), null)).isFalse();
        assertThat(validator.isValid("ө".repeat(36), null)).isTrue();   // 72 bytes
        assertThat(validator.isValid("ө".repeat(37), null)).isFalse();  // 74 bytes, still under 100 characters
        assertThat(validator.isValid(null, null)).isTrue();
    }

    /** Why the rule exists: BCrypt itself refuses a longer new password with an exception (was a 500). */
    @Test
    void bcryptRefusesWhatTheRuleRefuses() {
        var encoder = new BCryptPasswordEncoder(4);
        assertThat(encoder.encode("ө".repeat(36))).startsWith("$2a$");
        assertThatThrownBy(() -> encoder.encode("ө".repeat(37))).isInstanceOf(IllegalArgumentException.class);
    }
}
