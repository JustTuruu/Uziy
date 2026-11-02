package mn.uziy.backend.rejoin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class PhoneFingerprintTest {

    private final PhoneFingerprint fingerprint = new PhoneFingerprint("test-secret-of-enough-length-0123456789");

    @Test
    void theSamePhoneAlwaysGivesTheSameHash() {
        assertThat(fingerprint.of("99112233")).isEqualTo(fingerprint.of("99112233"));
    }

    @Test
    void theHashIs64HexCharactersAndNeverContainsTheNumber() {
        String hash = fingerprint.of("99112233");

        assertThat(hash).matches("[0-9a-f]{64}").doesNotContain("99112233");
    }

    @Test
    void differentPhonesGiveDifferentHashes() {
        assertThat(fingerprint.of("99112233")).isNotEqualTo(fingerprint.of("99112234"));
    }

    @Test
    void theHashDependsOnTheSecretSoItCannotBeRebuiltWithoutIt() {
        PhoneFingerprint other = new PhoneFingerprint("another-secret-of-enough-length-987654");

        assertThat(other.of("99112233")).isNotEqualTo(fingerprint.of("99112233"));
    }

    @Test
    void knownVectorMatchesHmacSha256() {
        // The well-known HMAC-SHA256 example: key "key", message "The quick brown fox jumps over the lazy dog".
        assertThat(new PhoneFingerprint("key").of("The quick brown fox jumps over the lazy dog"))
                .isEqualTo("f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8");
    }

    @Test
    void aBlankSecretRefusesToStart() {
        assertThatThrownBy(() -> new PhoneFingerprint(" ")).isInstanceOf(IllegalStateException.class);
    }
}
