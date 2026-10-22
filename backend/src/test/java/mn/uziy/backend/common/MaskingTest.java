package mn.uziy.backend.common;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class MaskingTest {

    @Test
    void keepsOnlyTheLastFourCharacters() {
        assertThat(Masking.lastFour("5001234567")).isEqualTo("•••• 4567");
        assertThat(Masking.lastFour("99001122")).isEqualTo("•••• 1122");
    }

    @Test
    void ignoresSurroundingSpaces() {
        assertThat(Masking.lastFour("  5001234567 ")).isEqualTo("•••• 4567");
    }

    @Test
    void aShortOrMissingValueIsHiddenCompletely() {
        assertThat(Masking.lastFour("1234")).isEqualTo("••••");
        assertThat(Masking.lastFour("1")).isEqualTo("••••");
        assertThat(Masking.lastFour("")).isEqualTo("••••");
        assertThat(Masking.lastFour(null)).isEqualTo("••••");
    }
}
