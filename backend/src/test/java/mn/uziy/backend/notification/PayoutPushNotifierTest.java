package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.payout.PayoutDecided;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

class PayoutPushNotifierTest {

    private final PayoutRepository payouts = mock(PayoutRepository.class);
    private final PushSender sender = mock(PushSender.class);
    private final DeviceTokenRepository deviceTokens = mock(DeviceTokenRepository.class);
    private final PayoutPushNotifier notifier =
            new PayoutPushNotifier(payouts, new PushMessageFactory(), sender, deviceTokens);

    private static PayoutDecided decided(PayoutStatus status) {
        return new PayoutDecided(9L, 42L, status, 1L);
    }

    private void stubPayout(PayoutStatus status, List<String> tokens) {
        when(payouts.findById(9L)).thenReturn(Optional.of(NotificationTestData.payout(9L, status)));
        when(deviceTokens.findTokensByUserId(42L)).thenReturn(tokens);
        when(sender.send(any(), anyList())).thenReturn(PushResult.none());
    }

    @Test
    void approvalIsPushedToEveryDeviceOfThatViewer() {
        stubPayout(PayoutStatus.APPROVED, List.of("a", "b"));

        notifier.onPayoutDecided(decided(PayoutStatus.APPROVED));

        ArgumentCaptor<PushMessage> msg = ArgumentCaptor.forClass(PushMessage.class);
        verify(sender).send(msg.capture(), eq(List.of("a", "b")));
        assertThat(msg.getValue().title()).isEqualTo("Мөнгө татах хүсэлт батлагдлаа");
        assertThat(msg.getValue().data()).containsEntry("type", "PAYOUT");
        verify(deviceTokens, never()).deleteAllByTokenIn(any());
    }

    @Test
    void rejectionIsPushedToo() {
        stubPayout(PayoutStatus.REJECTED, List.of("a"));

        notifier.onPayoutDecided(decided(PayoutStatus.REJECTED));

        ArgumentCaptor<PushMessage> msg = ArgumentCaptor.forClass(PushMessage.class);
        verify(sender).send(msg.capture(), eq(List.of("a")));
        assertThat(msg.getValue().title()).isEqualTo("Мөнгө татах хүсэлт татгалзагдлаа");
    }

    @Test
    void aViewerWithoutDevicesGetsNothingSent() {
        stubPayout(PayoutStatus.APPROVED, List.of());

        notifier.onPayoutDecided(decided(PayoutStatus.APPROVED));

        verifyNoInteractions(sender);
    }

    @Test
    void deadTokensAreRemoved() {
        stubPayout(PayoutStatus.APPROVED, List.of("live", "dead"));
        when(sender.send(any(), anyList())).thenReturn(new PushResult(List.of("dead")));

        notifier.onPayoutDecided(decided(PayoutStatus.APPROVED));

        verify(deviceTokens).deleteAllByTokenIn(List.of("dead"));
    }

    @Test
    void aMissingPayoutIsSkipped() {
        when(payouts.findById(9L)).thenReturn(Optional.empty());

        notifier.onPayoutDecided(decided(PayoutStatus.APPROVED));

        verifyNoInteractions(sender, deviceTokens);
    }

    @Test
    void aFailingSenderNeverEscapes() {
        stubPayout(PayoutStatus.APPROVED, List.of("a"));
        when(sender.send(any(), anyList())).thenThrow(new IllegalStateException("FCM down"));

        assertThatCode(() -> notifier.onPayoutDecided(decided(PayoutStatus.APPROVED)))
                .doesNotThrowAnyException();
    }

    @Test
    void runsAfterCommitOnThePushExecutor() throws NoSuchMethodException {
        var method = PayoutPushNotifier.class.getMethod("onPayoutDecided", PayoutDecided.class);

        assertThat(method.getAnnotation(TransactionalEventListener.class).phase())
                .isEqualTo(TransactionPhase.AFTER_COMMIT);
        assertThat(method.getAnnotation(Async.class).value()).isEqualTo(AsyncConfig.PUSH_EXECUTOR);
    }
}
