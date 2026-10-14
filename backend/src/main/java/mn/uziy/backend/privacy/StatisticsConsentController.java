package mn.uziy.backend.privacy;

import jakarta.validation.Valid;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter: the viewer reads and changes their own statistics consent. */
@RestController
@RequestMapping("/viewer/consents/statistics")
@PreAuthorize("hasRole('VIEWER')")
public class StatisticsConsentController {

    private final StatisticsConsentService consents;

    public StatisticsConsentController(StatisticsConsentService consents) {
        this.consents = consents;
    }

    @GetMapping
    public StatisticsConsentDto current(@Auth JwtPrincipal principal) {
        return consents.current(principal.userId());
    }

    @PutMapping
    public StatisticsConsentDto decide(@Valid @RequestBody DecideStatisticsConsentReq body,
                                       @Auth JwtPrincipal principal) {
        return consents.decide(principal.userId(), body.granted());
    }
}
