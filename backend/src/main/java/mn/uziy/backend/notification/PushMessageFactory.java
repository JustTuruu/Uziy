package mn.uziy.backend.notification;

import java.util.Locale;
import java.util.Map;
import mn.uziy.backend.domain.CampaignEntity;
import org.springframework.stereotype.Component;

/** Pattern: Factory — builds Mongolian push messages; other events add a method here. */
@Component
public class PushMessageFactory {

    static final String VIDEO_TITLE = "Шинэ видео";
    static final String SURVEY_TITLE = "Шинэ судалгаа";

    /** A newly live campaign; {@code advertiser} is the company name (or the campaign title). */
    public PushMessage campaignLive(CampaignEntity campaign, String advertiser) {
        String title = campaign.hasVideo() ? VIDEO_TITLE : SURVEY_TITLE;
        String body = advertiser + " · Үзээд " + formatTugrik(campaign.getRewardPerUser()) + " ₮ аваарай";
        return new PushMessage(title, body, Map.of(
                "type", "CAMPAIGN",
                "campaignId", String.valueOf(campaign.getId()),
                "hasVideo", String.valueOf(campaign.hasVideo())));
    }

    private static String formatTugrik(double amount) {
        return String.format(Locale.ROOT, "%,d", Math.round(amount));
    }
}
