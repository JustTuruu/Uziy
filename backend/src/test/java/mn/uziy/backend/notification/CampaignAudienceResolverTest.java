package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.TargetGender;
import org.junit.jupiter.api.Test;

class CampaignAudienceResolverTest {

    private final DeviceTokenRepository tokens = mock(DeviceTokenRepository.class);
    private final CampaignAudienceResolver resolver = new CampaignAudienceResolver(
            tokens, Clock.fixed(Instant.parse("2026-10-06T10:00:00Z"), ZoneOffset.UTC));

    @Test
    void ageRangeBecomesBirthDateBoundsFromTheClock() {
        CampaignEntity c = NotificationTestData.campaign(7L, true);
        c.setTargetGender(TargetGender.FEMALE);
        c.setTargetCity("Дархан");
        // 18..45 on 2026-10-06: born on/before 2008-10-06 and after 1980-10-06.
        when(tokens.findTokensForCampaign(
                7L, "FEMALE", "Дархан", LocalDate.of(1980, 10, 6), LocalDate.of(2008, 10, 6)))
                .thenReturn(List.of("a", "b"));

        assertThat(resolver.tokensFor(c)).containsExactly("a", "b");
    }
}
