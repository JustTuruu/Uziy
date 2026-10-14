package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class VerificationCodeGeneratorTest {

    private final VerificationCodeGenerator generator = new VerificationCodeGenerator();

    @Test
    void codesAreAlwaysSixDigitsIncludingLeadingZeros() {
        for (int i = 0; i < 2_000; i++) {
            assertThat(generator.next()).matches("\\d{" + VerificationCodeGenerator.LENGTH + "}");
        }
    }

    @Test
    void codesVary() {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 200; i++) {
            seen.add(generator.next());
        }
        assertThat(seen.size()).isGreaterThan(150);
    }
}
