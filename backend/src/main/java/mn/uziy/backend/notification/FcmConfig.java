package mn.uziy.backend.notification;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import mn.uziy.backend.config.AppProperties;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Firebase bootstrap — only when {@code uziy.push.enabled=true}; fails fast without credentials. */
@Configuration
@ConditionalOnProperty(prefix = "uziy.push", name = "enabled", havingValue = "true")
public class FcmConfig {

    @Bean
    public FirebaseApp firebaseApp(AppProperties props) {
        Path credentials = requireCredentials(props.push().credentialsPath());
        try (InputStream in = Files.newInputStream(credentials)) {
            return FirebaseApp.initializeApp(FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(in))
                    .build());
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot read FCM credentials at " + credentials, e);
        }
    }

    @Bean
    public FirebaseMessaging firebaseMessaging(FirebaseApp app) {
        return FirebaseMessaging.getInstance(app);
    }

    static Path requireCredentials(String credentialsPath) {
        if (credentialsPath == null || credentialsPath.isBlank()) {
            throw new IllegalStateException(
                    "uziy.push.enabled=true but FCM_CREDENTIALS_PATH (uziy.push.credentials-path) is not set");
        }
        Path path = Path.of(credentialsPath);
        if (!Files.isRegularFile(path)) {
            throw new IllegalStateException(
                    "uziy.push.enabled=true but the FCM credentials file does not exist: " + path);
        }
        return path;
    }
}
