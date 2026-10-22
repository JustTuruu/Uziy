package mn.uziy.backend.trusteddevice;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Base64;
import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class DeviceSecretsTest {

    private final DeviceSecrets secrets = new DeviceSecrets();

    @Test
    void aSecretIs32RandomBytesInUrlSafeBase64WithoutPadding() {
        String secret = secrets.next();

        assertThat(secret).hasSize(43).matches("[A-Za-z0-9_-]+");
        assertThat(Base64.getUrlDecoder().decode(secret)).hasSize(DeviceSecrets.SECRET_BYTES);
    }

    @Test
    void secretsDoNotRepeat() {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 1_000; i++) {
            seen.add(secrets.next());
        }

        assertThat(seen).hasSize(1_000);
    }

    @Test
    void theStoredFormIsTheHexSha256() {
        // The SHA-256 test vector for "abc" (FIPS 180-2).
        assertThat(DeviceSecrets.hash("abc"))
                .isEqualTo("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assertThat(DeviceSecrets.hash(secrets.next())).hasSize(64).matches("[0-9a-f]+");
    }

    @Test
    void theHashNeverContainsTheSecret() {
        String secret = secrets.next();

        assertThat(DeviceSecrets.hash(secret)).doesNotContain(secret);
    }
}
