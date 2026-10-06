package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import mn.uziy.backend.domain.CampaignEntity;
import org.junit.jupiter.api.Test;

class PushMessageFactoryTest {

    private final PushMessageFactory factory = new PushMessageFactory();

    @Test
    void videoCampaignGetsTheVideoTitleBodyAndDataPayload() {
        PushMessage m = factory.campaignLive(NotificationTestData.campaign(7L, true), "MobiCom");

        assertThat(m.title()).isEqualTo("Шинэ видео");
        assertThat(m.body()).isEqualTo("MobiCom · Үзээд 1,500 ₮ аваарай");
        assertThat(m.data()).isEqualTo(Map.of("type", "CAMPAIGN", "campaignId", "7", "hasVideo", "true"));
    }

    @Test
    void surveyOnlyCampaignGetsTheSurveyTitleAndHasVideoFalse() {
        PushMessage m = factory.campaignLive(NotificationTestData.campaign(8L, false), "Golomt");

        assertThat(m.title()).isEqualTo("Шинэ судалгаа");
        assertThat(m.data()).containsEntry("hasVideo", "false").containsEntry("campaignId", "8");
    }

    @Test
    void rewardIsRoundedToWholeTugrikWithThousandsSeparators() {
        CampaignEntity c = NotificationTestData.campaign(1L, true);
        c.setRewardPerUser(1234567.6);

        assertThat(factory.campaignLive(c, "X").body()).isEqualTo("X · Үзээд 1,234,568 ₮ аваарай");

        c.setRewardPerUser(700.0);
        assertThat(factory.campaignLive(c, "X").body()).contains("Үзээд 700 ₮");
    }
}
