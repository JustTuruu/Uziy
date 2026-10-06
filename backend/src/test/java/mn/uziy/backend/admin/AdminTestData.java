package mn.uziy.backend.admin;

import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;

/** Entity fixtures shared by the admin service tests. */
final class AdminTestData {

    private AdminTestData() {
    }

    static CampaignEntity campaign(long id, CampaignStatus status) {
        CampaignEntity c = new CampaignEntity();
        c.setId(id);
        c.setCompanyId(500L);
        c.setTitle("T");
        c.setDurationSeconds(30);
        c.setTargetGender(TargetGender.ALL);
        c.setMinAge(18);
        c.setMaxAge(45);
        c.setTargetCity("Улаанбаатар");
        c.setTotalBudget(1_000_000.0);
        c.setRemainingBudget(900_000.0);
        c.setCostPerView(1000.0);
        c.setRewardPerUser(700.0);
        c.setStatus(status);
        return c;
    }

    static PayoutEntity payout(long id) {
        PayoutEntity p = new PayoutEntity();
        p.setId(id);
        p.setUserId(42L);
        p.setAmount(500.0);
        p.setBank("Khan");
        p.setAccountNumber("1");
        p.setAccountName("X");
        p.setNationalId("Y");
        p.setStatus(PayoutStatus.PENDING);
        return p;
    }

    static UserEntity company(long id, String name) {
        UserEntity u = new UserEntity();
        u.setId(id);
        u.setPhoneNumber("88112233");
        u.setPasswordHash("x");
        u.setRole(Role.COMPANY);
        u.setCompanyName(name);
        u.setVerified(true);
        return u;
    }
}
