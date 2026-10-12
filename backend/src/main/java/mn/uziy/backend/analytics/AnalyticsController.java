package mn.uziy.backend.analytics;

import mn.uziy.backend.analytics.AnalyticsDtos.AnalyticsResponse;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for the company console's analytics page. */
@RestController
@RequestMapping("/company/analytics")
@PreAuthorize("hasRole('COMPANY')")
public class AnalyticsController {

    private final AnalyticsService analytics;

    public AnalyticsController(AnalyticsService analytics) {
        this.analytics = analytics;
    }

    @GetMapping
    public AnalyticsResponse get(
            @RequestParam(name = "days", defaultValue = "" + AnalyticsService.DEFAULT_DAYS) int days,
            @RequestParam(name = "campaignId", required = false) Long campaignId,
            @Auth JwtPrincipal principal) {
        return analytics.analytics(principal.userId(), days, campaignId);
    }
}
