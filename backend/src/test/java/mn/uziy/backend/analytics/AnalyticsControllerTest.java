package mn.uziy.backend.analytics;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import mn.uziy.backend.analytics.AnalyticsDtos.AnalyticsResponse;
import mn.uziy.backend.analytics.AnalyticsDtos.Totals;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.Test;

class AnalyticsControllerTest {

    @Test
    void passesTheCallersIdTheWindowAndTheCampaignFilterToTheService() {
        AnalyticsService service = mock(AnalyticsService.class);
        var response = new AnalyticsResponse(14, new Totals(0, 0, 0, 0, 0, null),
                List.of(), List.of(), null, List.of(), List.of());
        when(service.analytics(500L, 14, 3L)).thenReturn(response);

        var out = new AnalyticsController(service).get(14, 3L, new JwtPrincipal(500L, Role.COMPANY));

        assertThat(out).isSameAs(response);
    }
}
