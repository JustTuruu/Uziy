package mn.uziy.backend.notification;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import mn.uziy.backend.domain.CampaignEntity;
import org.springframework.stereotype.Component;

/**
 * Turns a campaign's targeting rules into device tokens. Converts the age range to birth-date
 * bounds with the injected Clock so the database can use plain date comparisons.
 */
@Component
public class CampaignAudienceResolver {

    private final DeviceTokenRepository tokens;
    private final Clock clock;

    public CampaignAudienceResolver(DeviceTokenRepository tokens, Clock clock) {
        this.tokens = tokens;
        this.clock = clock;
    }

    public List<String> tokensFor(CampaignEntity campaign) {
        LocalDate today = LocalDate.now(clock);
        // age >= minAge  <=>  born on or before today - minAge years
        // age <= maxAge  <=>  born after        today - (maxAge + 1) years
        LocalDate bornOnOrBefore = today.minusYears(campaign.getMinAge());
        LocalDate bornAfter = today.minusYears(campaign.getMaxAge() + 1L);
        return tokens.findTokensForCampaign(
                campaign.getId(),
                campaign.getTargetGender().name(),
                campaign.getTargetCity(),
                bornAfter,
                bornOnOrBefore);
    }
}
