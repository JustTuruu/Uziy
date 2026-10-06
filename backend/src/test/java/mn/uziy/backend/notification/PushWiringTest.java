package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;

import com.google.firebase.messaging.FirebaseMessaging;
import mn.uziy.backend.config.AppProperties;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;

/** Which PushSender is wired for uziy.push.enabled, and the fail-fast of the FCM bootstrap. */
class PushWiringTest {

    @Configuration
    @EnableConfigurationProperties(AppProperties.class)
    static class Props {
    }

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withUserConfiguration(Props.class, LoggingPushSender.class, FcmPushSender.class)
            .withBean(FirebaseMessaging.class, () -> Mockito.mock(FirebaseMessaging.class));

    @Test
    void defaultsToTheLoggingSender() {
        runner.run(ctx -> assertThat(ctx).hasSingleBean(PushSender.class).hasSingleBean(LoggingPushSender.class));
    }

    @Test
    void disabledUsesTheLoggingSender() {
        runner.withPropertyValues("uziy.push.enabled=false")
                .run(ctx -> assertThat(ctx.getBean(PushSender.class)).isInstanceOf(LoggingPushSender.class));
    }

    @Test
    void enabledUsesFcm() {
        runner.withPropertyValues("uziy.push.enabled=true")
                .run(ctx -> assertThat(ctx.getBean(PushSender.class)).isInstanceOf(FcmPushSender.class));
    }

    @Test
    void enabledWithoutCredentialsFileFailsStartupWithAClearMessage() {
        new ApplicationContextRunner()
                .withUserConfiguration(Props.class, FcmConfig.class)
                .withPropertyValues("uziy.push.enabled=true", "uziy.push.credentials-path=/nope/missing.json")
                .run(ctx -> assertThat(ctx).hasFailed().getFailure()
                        .hasRootCauseInstanceOf(IllegalStateException.class)
                        .rootCause().hasMessageContaining("/nope/missing.json"));
    }

    @Test
    void fcmConfigIsInactiveWhenDisabled() {
        new ApplicationContextRunner()
                .withUserConfiguration(Props.class, FcmConfig.class)
                .run(ctx -> assertThat(ctx).doesNotHaveBean(FcmConfig.class));
    }
}
