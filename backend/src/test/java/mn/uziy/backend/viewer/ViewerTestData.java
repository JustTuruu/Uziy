package mn.uziy.backend.viewer;

import java.time.LocalDate;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;

/** Entity fixtures shared by the viewer service tests. */
public final class ViewerTestData {

    private ViewerTestData() {
    }

    static UserEntity viewer() {
        UserEntity u = new UserEntity();
        u.setId(42L);
        u.setPhoneNumber("77000001");
        u.setPasswordHash("x");
        u.setRole(Role.VIEWER);
        u.setGender(Gender.MALE);
        u.setBirthDate(LocalDate.now().minusYears(26));
        u.setCity("Улаанбаатар");
        u.setBalance(0.0);
        return u;
    }

    public static CampaignEntity sampleCampaign(long id) {
        CampaignEntity c = new CampaignEntity();
        c.setId(id);
        c.setCompanyId(500L);
        c.setTitle("Test");
        c.setDurationSeconds(30);
        c.setTargetGender(TargetGender.ALL);
        c.setMinAge(18);
        c.setMaxAge(45);
        c.setTargetCity("Улаанбаатар");
        c.setTotalBudget(5_000_000.0);
        c.setRemainingBudget(5_000_000.0);
        c.setCostPerView(1000.0);
        c.setRewardPerUser(700.0);
        c.setStatus(CampaignStatus.ACTIVE);
        return c;
    }
}
