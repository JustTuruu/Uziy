package mn.uziy.backend.company;

import static org.mockito.Mockito.when;

import java.util.Optional;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PlatformSettingsEntity;
import mn.uziy.backend.domain.PlatformSettingsRepository;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.security.JwtPrincipal;

/** Builders shared by the company service tests. */
final class CompanyTestFixtures {

    static final JwtPrincipal PRINCIPAL = new JwtPrincipal(500L, Role.COMPANY);

    private CompanyTestFixtures() {
    }

    /** Stubs the singleton platform_settings row. */
    static void settings(PlatformSettingsRepository repo, int commission, int minReward) {
        PlatformSettingsEntity s = new PlatformSettingsEntity();
        s.setId(1);
        s.setCommissionPercent(commission);
        s.setMinRewardPerViewer(minReward);
        when(repo.findById(1)).thenReturn(Optional.of(s));
    }

    static CampaignEntity sampleCampaign(long id, long ownerId, CampaignStatus status) {
        CampaignEntity c = new CampaignEntity();
        c.setId(id);
        c.setCompanyId(ownerId);
        c.setTitle("T" + id);
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
        c.setTargetViewers(1000);
        c.setCommissionPercent(30);
        return c;
    }

    static CampaignEntity sampleCampaign(long id) {
        return sampleCampaign(id, 500L, CampaignStatus.ACTIVE);
    }
}
