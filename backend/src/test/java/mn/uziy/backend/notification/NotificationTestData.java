package mn.uziy.backend.notification;

import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.TargetGender;

/** Builder-style fixtures shared by the notification tests. */
final class NotificationTestData {

    private NotificationTestData() {
    }

    static CampaignEntity campaign(long id, boolean hasVideo) {
        CampaignEntity c = new CampaignEntity();
        c.setId(id);
        c.setCompanyId(500L);
        c.setTitle("Зуны хямдрал");
        c.setHasVideo(hasVideo);
        c.setTargetGender(TargetGender.ALL);
        c.setMinAge(18);
        c.setMaxAge(45);
        c.setTargetCity("ALL");
        c.setRewardPerUser(1500.0);
        c.setStatus(CampaignStatus.ACTIVE);
        return c;
    }
}
