package mn.uziy.backend.notification;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Pattern: Strategy — sends through Firebase Cloud Messaging (Android + iOS via APNs bridge).
 * Pattern: Template Method — {@link #send} fixes the flow (batch, send, collect dead tokens)
 * while {@link #buildRequest} and {@link #collectInvalid} are the steps.
 */
@Component
@ConditionalOnProperty(prefix = "uziy.push", name = "enabled", havingValue = "true")
public class FcmPushSender implements PushSender {

    /** FCM's hard limit of tokens per multicast request. */
    static final int BATCH_SIZE = 500;
    static final String ANDROID_CHANNEL_ID = "campaigns";
    private static final String APNS_DEFAULT_SOUND = "default";
    /** Error codes meaning "this token will never work again". */
    private static final Set<MessagingErrorCode> DEAD_TOKEN_CODES =
            Set.of(MessagingErrorCode.UNREGISTERED, MessagingErrorCode.INVALID_ARGUMENT);

    private static final Logger LOG = LoggerFactory.getLogger(FcmPushSender.class);

    private final FirebaseMessaging messaging;

    public FcmPushSender(FirebaseMessaging messaging) {
        this.messaging = messaging;
    }

    @Override
    public PushResult send(PushMessage message, List<String> tokens) {
        List<String> invalid = new ArrayList<>();
        for (int from = 0; from < tokens.size(); from += BATCH_SIZE) {
            List<String> batch = tokens.subList(from, Math.min(from + BATCH_SIZE, tokens.size()));
            try {
                BatchResponse response = messaging.sendEachForMulticast(buildRequest(message, batch));
                invalid.addAll(collectInvalid(batch, response));
            } catch (FirebaseMessagingException | RuntimeException e) {
                LOG.warn("FCM batch of {} tokens failed, continuing with the next one", batch.size(), e);
            }
        }
        return new PushResult(invalid);
    }

    private static MulticastMessage buildRequest(PushMessage message, List<String> batch) {
        return MulticastMessage.builder()
                .addAllTokens(batch)
                .setNotification(Notification.builder()
                        .setTitle(message.title())
                        .setBody(message.body())
                        .build())
                .putAllData(message.data())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder().setChannelId(ANDROID_CHANNEL_ID).build())
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder().setSound(APNS_DEFAULT_SOUND).build())
                        .build())
                .build();
    }

    private static List<String> collectInvalid(List<String> batch, BatchResponse response) {
        List<String> invalid = new ArrayList<>();
        List<SendResponse> responses = response.getResponses();
        for (int i = 0; i < responses.size() && i < batch.size(); i++) {
            SendResponse r = responses.get(i);
            if (!r.isSuccessful() && isDeadToken(r.getException())) {
                invalid.add(batch.get(i));
            }
        }
        return invalid;
    }

    private static boolean isDeadToken(FirebaseMessagingException e) {
        return e != null && e.getMessagingErrorCode() != null
                && DEAD_TOKEN_CODES.contains(e.getMessagingErrorCode());
    }
}
