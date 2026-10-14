package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
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

    @Test
    void approvedPayoutSaysWhereTheMoneyGoes() {
        PushMessage m = factory.payoutDecided(NotificationTestData.payout(9L, PayoutStatus.APPROVED));

        assertThat(m.title()).isEqualTo("Мөнгө татах хүсэлт батлагдлаа");
        assertThat(m.body()).isEqualTo("5,000 ₮ Khan Bank дансанд тань шилжинэ");
        assertThat(m.data()).isEqualTo(Map.of("type", "PAYOUT", "payoutId", "9", "status", "APPROVED"));
    }

    @Test
    void rejectedPayoutSaysTheMoneyIsBackWithTheReason() {
        PayoutEntity p = NotificationTestData.payout(9L, PayoutStatus.REJECTED);
        p.setRejectReason("  Дансны нэр таарахгүй ");

        PushMessage m = factory.payoutDecided(p);

        assertThat(m.title()).isEqualTo("Мөнгө татах хүсэлт татгалзагдлаа");
        assertThat(m.body()).isEqualTo("5,000 ₮ хэтэвчинд тань буцлаа. Шалтгаан: Дансны нэр таарахгүй");
        assertThat(m.data()).containsEntry("status", "REJECTED");
    }

    @Test
    void rejectedPayoutWithoutAReasonEndsAfterTheRefund() {
        PayoutEntity p = NotificationTestData.payout(9L, PayoutStatus.REJECTED);
        p.setRejectReason(" ");

        assertThat(factory.payoutDecided(p).body()).isEqualTo("5,000 ₮ хэтэвчинд тань буцлаа");
    }
}
