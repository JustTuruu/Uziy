package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.SendResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.IntStream;
import org.junit.jupiter.api.Test;

class FcmPushSenderTest {

    private static final PushMessage MESSAGE = new PushMessage("t", "b", Map.of("type", "CAMPAIGN"));

    private final FirebaseMessaging messaging = mock(FirebaseMessaging.class);
    private final FcmPushSender sender = new FcmPushSender(messaging);

    private static List<String> tokens(int n) {
        return IntStream.range(0, n).mapToObj(i -> "tok" + i).toList();
    }

    private static SendResponse ok() {
        SendResponse r = mock(SendResponse.class);
        when(r.isSuccessful()).thenReturn(true);
        return r;
    }

    private static SendResponse failed(MessagingErrorCode code) {
        FirebaseMessagingException e = mock(FirebaseMessagingException.class);
        when(e.getMessagingErrorCode()).thenReturn(code);
        SendResponse r = mock(SendResponse.class);
        when(r.isSuccessful()).thenReturn(false);
        when(r.getException()).thenReturn(e);
        return r;
    }

    private static BatchResponse batch(List<SendResponse> responses) {
        BatchResponse b = mock(BatchResponse.class);
        when(b.getResponses()).thenReturn(responses);
        return b;
    }

    private static List<SendResponse> allOk(int n) {
        List<SendResponse> list = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            list.add(ok());
        }
        return list;
    }

    @Test
    void sendsOneMulticastRequestPerFiveHundredTokens() throws Exception {
        BatchResponse b1 = batch(allOk(500));
        BatchResponse b2 = batch(allOk(500));
        BatchResponse b3 = batch(allOk(100));
        when(messaging.sendEachForMulticast(any(MulticastMessage.class))).thenReturn(b1, b2, b3);

        PushResult result = sender.send(MESSAGE, tokens(1100));

        verify(messaging, times(3)).sendEachForMulticast(any(MulticastMessage.class));
        assertThat(result.invalidTokens()).isEmpty();
    }

    @Test
    void exactlyOneBatchForUpToFiveHundredAndNoCallForNone() throws Exception {
        BatchResponse full = batch(allOk(500));
        when(messaging.sendEachForMulticast(any(MulticastMessage.class))).thenReturn(full);

        sender.send(MESSAGE, tokens(500));
        verify(messaging, times(1)).sendEachForMulticast(any(MulticastMessage.class));

        sender.send(MESSAGE, List.of());
        verify(messaging, times(1)).sendEachForMulticast(any(MulticastMessage.class));
    }

    @Test
    void unregisteredAndInvalidArgumentTokensAreCollectedWithTheirBatchOffset() throws Exception {
        List<SendResponse> first = allOk(500);
        first.set(3, failed(MessagingErrorCode.UNREGISTERED));
        List<SendResponse> second = allOk(2);
        second.set(1, failed(MessagingErrorCode.INVALID_ARGUMENT));
        BatchResponse b1 = batch(first);
        BatchResponse b2 = batch(second);
        when(messaging.sendEachForMulticast(any(MulticastMessage.class))).thenReturn(b1, b2);

        PushResult result = sender.send(MESSAGE, tokens(502));

        assertThat(result.invalidTokens()).containsExactly("tok3", "tok501");
    }

    @Test
    void transientFailuresAreNotReportedAsInvalid() throws Exception {
        List<SendResponse> responses = List.of(
                failed(MessagingErrorCode.UNAVAILABLE), failed(MessagingErrorCode.INTERNAL),
                failed(MessagingErrorCode.QUOTA_EXCEEDED), failed(null));
        BatchResponse b = batch(responses);
        when(messaging.sendEachForMulticast(any(MulticastMessage.class))).thenReturn(b);

        assertThat(sender.send(MESSAGE, tokens(4)).invalidTokens()).isEmpty();
    }

    @Test
    void aFailingBatchIsLoggedAndTheNextOneStillSent() throws Exception {
        List<SendResponse> second = allOk(1);
        second.set(0, failed(MessagingErrorCode.UNREGISTERED));
        BatchResponse b2 = batch(second);
        when(messaging.sendEachForMulticast(any(MulticastMessage.class)))
                .thenThrow(new IllegalStateException("network"))
                .thenReturn(b2);

        PushResult result = sender.send(MESSAGE, tokens(501));

        verify(messaging, times(2)).sendEachForMulticast(any(MulticastMessage.class));
        assertThat(result.invalidTokens()).containsExactly("tok500");
    }

    @Test
    void checkedFirebaseExceptionNeverEscapes() throws Exception {
        FirebaseMessagingException boom = mock(FirebaseMessagingException.class);
        when(messaging.sendEachForMulticast(any(MulticastMessage.class))).thenThrow(boom);

        assertThat(sender.send(MESSAGE, tokens(2)).invalidTokens()).isEmpty();
    }
}
