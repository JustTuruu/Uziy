package mn.uziy.backend.otp;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class OtpCodeGeneratorTest {

    private final OtpCodeGenerator generator = new OtpCodeGenerator();

    @Test
    void codesAreAlwaysSixDigitsIncludingLeadingZeros() {
        for (int i = 0; i < 2_000; i++) {
            assertThat(generator.next()).matches("\\d{" + OtpCodeGenerator.LENGTH + "}");
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
