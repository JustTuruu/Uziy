package mn.uziy.backend.notification;

import java.util.List;
import mn.uziy.backend.company.CampaignStatusChanged;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Pattern: Observer — pushes a notification once a campaign first goes live (PENDING → ACTIVE).
 * Runs after the approving transaction committed and off the request thread, and swallows
 * every failure: a push problem must never affect campaign approval.
 */
@Component
public class CampaignPushNotifier {

    private static final Logger LOG = LoggerFactory.getLogger(CampaignPushNotifier.class);

    private final CampaignRepository campaigns;
    private final UserRepository users;
    private final CampaignAudienceResolver audience;
    private final PushMessageFactory messages;
    private final PushSender sender;
    private final DeviceTokenRepository deviceTokens;

    public CampaignPushNotifier(CampaignRepository campaigns, UserRepository users,
                                CampaignAudienceResolver audience, PushMessageFactory messages,
                                PushSender sender, DeviceTokenRepository deviceTokens) {
        this.campaigns = campaigns;
        this.users = users;
        this.audience = audience;
        this.messages = messages;
        this.sender = sender;
        this.deviceTokens = deviceTokens;
    }

    @Async(AsyncConfig.PUSH_EXECUTOR)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onCampaignStatusChanged(CampaignStatusChanged event) {
        if (event.from() != CampaignStatus.PENDING || event.to() != CampaignStatus.ACTIVE) {
            return;
        }
        try {
            notifyViewers(event.campaignId());
        } catch (RuntimeException e) {
            LOG.error("push for campaign {} failed; approval is unaffected", event.campaignId(), e);
        }
    }

    private void notifyViewers(long campaignId) {
        CampaignEntity campaign = campaigns.findById(campaignId).orElse(null);
        if (campaign == null) {
            LOG.warn("push skipped: campaign {} not found", campaignId);
            return;
        }
        List<String> tokens = audience.tokensFor(campaign);
        if (tokens.isEmpty()) {
            return;
        }
        PushResult result = sender.send(messages.campaignLive(campaign, advertiserOf(campaign)), tokens);
        if (!result.invalidTokens().isEmpty()) {
            deviceTokens.deleteAllByTokenIn(result.invalidTokens());
        }
        LOG.info("push for campaign {} sent to {} devices, {} dead tokens removed",
                campaignId, tokens.size(), result.invalidTokens().size());
    }

    private String advertiserOf(CampaignEntity campaign) {
        return users.findById(campaign.getCompanyId())
                .map(u -> u.getCompanyName())
                .filter(name -> !name.isBlank())
                .orElse(campaign.getTitle());
    }
}
