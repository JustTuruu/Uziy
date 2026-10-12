package mn.uziy.backend.viewer;

import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;

/**
 * The audience rule of a campaign, applied to one viewer: gender, age range and city. The same rule the home
 * feed query applies in SQL, here as code so the reward step can refuse a viewer the campaign was never
 * meant for (a stolen or guessed campaign id must not pay out).
 */
final class CampaignTargeting {

    static final String ALL_CITIES = "ALL";

    private CampaignTargeting() {
    }

    /** False for a viewer whose profile is incomplete: they are never in any audience. */
    static boolean matches(CampaignEntity campaign, UserEntity viewer) {
        if (viewer.getGender() == null || viewer.getAge() == null || viewer.getCity() == null) {
            return false;
        }
        boolean genderOk = campaign.getTargetGender() == TargetGender.ALL
                || campaign.getTargetGender().name().equals(viewer.getGender().name());
        int age = viewer.getAge();
        boolean ageOk = age >= campaign.getMinAge() && age <= campaign.getMaxAge();
        boolean cityOk = ALL_CITIES.equals(campaign.getTargetCity())
                || campaign.getTargetCity().equals(viewer.getCity());
        return genderOk && ageOk && cityOk;
    }
}
