package mn.uziy.backend.viewer;

import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static mn.uziy.backend.viewer.ViewerTestData.viewer;
import static org.assertj.core.api.Assertions.assertThat;

import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

/** The standard test viewer is a 26-year-old man in Улаанбаатар; the sample campaign is for 18–45, everyone, that city. */
class CampaignTargetingTest {

    private final UserEntity man = viewer();

    @Test
    void aViewerInsideEveryDimensionMatches() {
        assertThat(CampaignTargeting.matches(sampleCampaign(1), man)).isTrue();
    }

    @Test
    void genderMustMatchUnlessTheCampaignIsForEveryone() {
        CampaignEntity c = sampleCampaign(1);
        c.setTargetGender(TargetGender.MALE);
        assertThat(CampaignTargeting.matches(c, man)).isTrue();
        c.setTargetGender(TargetGender.FEMALE);
        assertThat(CampaignTargeting.matches(c, man)).isFalse();
    }

    @Test
    void ageRangeIsInclusiveAtBothEnds() {
        CampaignEntity c = sampleCampaign(1);
        int age = man.getAge();
        c.setMinAge(age);
        c.setMaxAge(age);
        assertThat(CampaignTargeting.matches(c, man)).isTrue();
        c.setMinAge(age + 1);
        c.setMaxAge(age + 10);
        assertThat(CampaignTargeting.matches(c, man)).isFalse();
        c.setMinAge(age - 10);
        c.setMaxAge(age - 1);
        assertThat(CampaignTargeting.matches(c, man)).isFalse();
    }

    @Test
    void cityMustMatchUnlessTheCampaignIsForAllCities() {
        CampaignEntity c = sampleCampaign(1);
        c.setTargetCity("ALL");
        assertThat(CampaignTargeting.matches(c, man)).isTrue();
        c.setTargetCity("Дархан");
        assertThat(CampaignTargeting.matches(c, man)).isFalse();
    }

    @Test
    void aViewerWithAnIncompleteProfileIsInNoAudience() {
        UserEntity noCity = viewer();
        noCity.setCity(null);
        UserEntity noGender = viewer();
        noGender.setGender(null);
        UserEntity noBirth = viewer();
        noBirth.setBirthDate(null);

        assertThat(CampaignTargeting.matches(sampleCampaign(1), noCity)).isFalse();
        assertThat(CampaignTargeting.matches(sampleCampaign(1), noGender)).isFalse();
        assertThat(CampaignTargeting.matches(sampleCampaign(1), noBirth)).isFalse();
    }
}
