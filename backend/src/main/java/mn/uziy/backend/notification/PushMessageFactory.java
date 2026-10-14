package mn.uziy.backend.notification;

import java.util.Locale;
import java.util.Map;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Component;

/** Pattern: Factory — builds Mongolian push messages; other events add a method here. */
@Component
public class PushMessageFactory {

    static final String VIDEO_TITLE = "Шинэ видео";
    static final String SURVEY_TITLE = "Шинэ судалгаа";
    static final String PAYOUT_APPROVED_TITLE = "Мөнгө татах хүсэлт батлагдлаа";
    static final String PAYOUT_REJECTED_TITLE = "Мөнгө татах хүсэлт татгалзагдлаа";

    /** A newly live campaign; {@code advertiser} is the company name (or the campaign title). */
    public PushMessage campaignLive(CampaignEntity campaign, String advertiser) {
        String title = campaign.hasVideo() ? VIDEO_TITLE : SURVEY_TITLE;
        String body = advertiser + " · Үзээд " + formatTugrik(campaign.getRewardPerUser()) + " ₮ аваарай";
        return new PushMessage(title, body, Map.of(
                "type", "CAMPAIGN",
                "campaignId", String.valueOf(campaign.getId()),
                "hasVideo", String.valueOf(campaign.hasVideo())));
    }

    /**
     * A viewer's payout request was decided. Approved: the money goes to their bank account;
     * rejected: it is back in the wallet, with the admin's reason when there is one.
     */
    public PushMessage payoutDecided(PayoutEntity payout) {
        String amount = formatTugrik(payout.getAmount()) + " ₮";
        boolean approved = payout.getStatus() == PayoutStatus.APPROVED;
        String title = approved ? PAYOUT_APPROVED_TITLE : PAYOUT_REJECTED_TITLE;
        String body = approved
                ? amount + " " + payout.getBank() + " дансанд тань шилжинэ"
                : amount + " хэтэвчинд тань буцлаа" + reasonSuffix(payout.getRejectReason());
        return new PushMessage(title, body, Map.of(
                "type", "PAYOUT",
                "payoutId", String.valueOf(payout.getId()),
                "status", payout.getStatus().name()));
    }

    private static String reasonSuffix(@Nullable String reason) {
        return reason == null || reason.isBlank() ? "" : ". Шалтгаан: " + reason.strip();
    }

    private static String formatTugrik(double amount) {
        return String.format(Locale.ROOT, "%,d", Math.round(amount));
    }
}
