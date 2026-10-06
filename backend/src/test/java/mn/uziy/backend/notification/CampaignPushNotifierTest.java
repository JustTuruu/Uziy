package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import mn.uziy.backend.company.CampaignStatusChanged;
import mn.uziy.backend.domain.CampaignActor;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

class CampaignPushNotifierTest {

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final CampaignAudienceResolver audience = mock(CampaignAudienceResolver.class);
    private final PushSender sender = mock(PushSender.class);
    private final DeviceTokenRepository deviceTokens = mock(DeviceTokenRepository.class);
    private final CampaignPushNotifier notifier = new CampaignPushNotifier(
            campaigns, users, audience, new PushMessageFactory(), sender, deviceTokens);

    private static CampaignStatusChanged change(CampaignStatus from, CampaignStatus to) {
        return new CampaignStatusChanged(7L, from, to, CampaignActor.ADMIN);
    }

    private CampaignEntity stubCampaign(boolean hasVideo) {
        CampaignEntity c = NotificationTestData.campaign(7L, hasVideo);
        when(campaigns.findById(7L)).thenReturn(Optional.of(c));
        when(audience.tokensFor(c)).thenReturn(List.of("t1", "t2"));
        when(sender.send(any(), anyList())).thenReturn(PushResult.none());
        return c;
    }

    private void company(String name) {
        UserEntity u = new UserEntity();
        u.setCompanyName(name);
        when(users.findById(500L)).thenReturn(Optional.of(u));
    }

    @Test
    void firstApprovalPendingToActiveSendsToTheAudience() {
        stubCampaign(true);
        company("MobiCom");

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        ArgumentCaptor<PushMessage> msg = ArgumentCaptor.forClass(PushMessage.class);
        verify(sender).send(msg.capture(), org.mockito.ArgumentMatchers.eq(List.of("t1", "t2")));
        assertThat(msg.getValue().title()).isEqualTo("Шинэ видео");
        assertThat(msg.getValue().body()).isEqualTo("MobiCom · Үзээд 1,500 ₮ аваарай");
        verify(deviceTokens, never()).deleteAllByTokenIn(any());
    }

    @Test
    void resumeFromPausedDoesNotNotify() {
        notifier.onCampaignStatusChanged(change(CampaignStatus.PAUSED, CampaignStatus.ACTIVE));

        verifyNoInteractions(campaigns, sender, audience);
    }

    @Test
    void otherTransitionsDoNotNotify() {
        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.REJECTED));
        notifier.onCampaignStatusChanged(change(CampaignStatus.ACTIVE, CampaignStatus.PAUSED));

        verifyNoInteractions(campaigns, sender);
    }

    @Test
    void surveyOnlyCampaignGetsTheSurveyMessageAndFallsBackToTheTitleWithoutACompanyName() {
        stubCampaign(false);
        when(users.findById(500L)).thenReturn(Optional.empty());

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        ArgumentCaptor<PushMessage> msg = ArgumentCaptor.forClass(PushMessage.class);
        verify(sender).send(msg.capture(), anyList());
        assertThat(msg.getValue().title()).isEqualTo("Шинэ судалгаа");
        assertThat(msg.getValue().body()).startsWith("Зуны хямдрал · ");
        assertThat(msg.getValue().data()).containsEntry("hasVideo", "false");
    }

    @Test
    void blankCompanyNameAlsoFallsBackToTheCampaignTitle() {
        stubCampaign(true);
        company("  ");

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        ArgumentCaptor<PushMessage> msg = ArgumentCaptor.forClass(PushMessage.class);
        verify(sender).send(msg.capture(), anyList());
        assertThat(msg.getValue().body()).startsWith("Зуны хямдрал · ");
    }

    @Test
    void invalidTokensReportedBySenderAreDeleted() {
        CampaignEntity c = stubCampaign(true);
        company("MobiCom");
        when(sender.send(any(), anyList())).thenReturn(new PushResult(List.of("t2")));

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        verify(deviceTokens).deleteAllByTokenIn(List.of("t2"));
        assertThat(c.getStatus()).isEqualTo(CampaignStatus.ACTIVE);
    }

    @Test
    void emptyAudienceSendsNothing() {
        CampaignEntity c = NotificationTestData.campaign(7L, true);
        when(campaigns.findById(7L)).thenReturn(Optional.of(c));
        when(audience.tokensFor(c)).thenReturn(List.of());

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        verifyNoInteractions(sender);
    }

    @Test
    void missingCampaignIsSkippedQuietly() {
        when(campaigns.findById(7L)).thenReturn(Optional.empty());

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        verifyNoInteractions(sender);
    }

    @Test
    void senderExceptionIsSwallowed() {
        stubCampaign(true);
        company("MobiCom");
        when(sender.send(any(), anyList())).thenThrow(new IllegalStateException("fcm down"));

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        verify(deviceTokens, never()).deleteAllByTokenIn(any());
    }

    @Test
    void repositoryExceptionIsSwallowed() {
        when(campaigns.findById(7L)).thenThrow(new IllegalStateException("db down"));

        notifier.onCampaignStatusChanged(change(CampaignStatus.PENDING, CampaignStatus.ACTIVE));

        verifyNoInteractions(sender);
    }

    @Test
    void listenerRunsAsyncAfterCommit() throws NoSuchMethodException {
        var method = CampaignPushNotifier.class.getMethod("onCampaignStatusChanged", CampaignStatusChanged.class);

        assertThat(method.getAnnotation(Async.class).value()).isEqualTo(AsyncConfig.PUSH_EXECUTOR);
        assertThat(method.getAnnotation(TransactionalEventListener.class).phase())
                .isEqualTo(TransactionPhase.AFTER_COMMIT);
    }
}
