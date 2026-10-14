package mn.uziy.backend.notification;

import java.util.List;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.payout.PayoutDecided;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Pattern: Observer — tells a viewer on their phone that an admin approved or rejected their
 * payout request. Runs after the decision committed and off the request thread, and swallows
 * every failure: a push problem must never affect the decision itself.
 */
@Component
public class PayoutPushNotifier {

    private static final Logger LOG = LoggerFactory.getLogger(PayoutPushNotifier.class);

    private final PayoutRepository payouts;
    private final PushMessageFactory messages;
    private final PushSender sender;
    private final DeviceTokenRepository deviceTokens;

    public PayoutPushNotifier(PayoutRepository payouts, PushMessageFactory messages,
                              PushSender sender, DeviceTokenRepository deviceTokens) {
        this.payouts = payouts;
        this.messages = messages;
        this.sender = sender;
        this.deviceTokens = deviceTokens;
    }

    @Async(AsyncConfig.PUSH_EXECUTOR)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onPayoutDecided(PayoutDecided event) {
        try {
            notifyViewer(event);
        } catch (RuntimeException e) {
            LOG.error("push for payout {} failed; the decision is unaffected", event.payoutId(), e);
        }
    }

    private void notifyViewer(PayoutDecided event) {
        PayoutEntity payout = payouts.findById(event.payoutId()).orElse(null);
        if (payout == null) {
            LOG.warn("push skipped: payout {} not found", event.payoutId());
            return;
        }
        List<String> tokens = deviceTokens.findTokensByUserId(event.userId());
        if (tokens.isEmpty()) {
            return;
        }
        PushResult result = sender.send(messages.payoutDecided(payout), tokens);
        if (!result.invalidTokens().isEmpty()) {
            deviceTokens.deleteAllByTokenIn(result.invalidTokens());
        }
        LOG.info("push for payout {} sent to {} devices", event.payoutId(), tokens.size());
    }
}
