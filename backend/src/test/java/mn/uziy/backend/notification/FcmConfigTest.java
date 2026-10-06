package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class FcmConfigTest {

    @Test
    void blankPathFailsFastNamingTheEnvVar() {
        assertThatThrownBy(() -> FcmConfig.requireCredentials(" "))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("FCM_CREDENTIALS_PATH");
    }

    @Test
    void missingFileFailsFastNamingThePath() {
        assertThatThrownBy(() -> FcmConfig.requireCredentials("/no/such/file.json"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("/no/such/file.json");
    }

    @Test
    void existingFileIsAccepted(@TempDir Path dir) throws IOException {
        Path file = Files.writeString(dir.resolve("sa.json"), "{}");

        assertThat(FcmConfig.requireCredentials(file.toString())).isEqualTo(file);
    }
}
