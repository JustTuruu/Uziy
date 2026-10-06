package mn.uziy.backend.company;

import jakarta.validation.Valid;
import java.util.List;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for the company console — behaviour lives in the two services. */
@RestController
@RequestMapping("/company")
@PreAuthorize("hasRole('COMPANY')")
public class CompanyController {

    private final CampaignService campaigns;
    private final CampaignPaymentService payments;

    public CompanyController(CampaignService campaigns, CampaignPaymentService payments) {
        this.campaigns = campaigns;
        this.payments = payments;
    }

    @GetMapping("/campaigns")
    public List<CampaignDto> list(@Auth JwtPrincipal principal) {
        return campaigns.list(principal.userId());
    }

    @GetMapping("/campaigns/{id}")
    public CampaignDto get(@PathVariable("id") long id, @Auth JwtPrincipal principal) {
        return campaigns.get(principal.userId(), id);
    }

    @PostMapping("/campaigns")
    public CampaignDto create(@Valid @RequestBody CreateCampaignReq body, @Auth JwtPrincipal principal) {
        return campaigns.create(principal.userId(), body);
    }

    @PostMapping("/campaigns/{id}/pay")
    public PayCampaignResponse pay(@PathVariable("id") long id, @Auth JwtPrincipal principal) {
        return payments.pay(principal.userId(), id);
    }

    @GetMapping("/payments")
    public List<PaymentDto> payments(@Auth JwtPrincipal principal) {
        return payments.list(principal.userId());
    }

    @PatchMapping("/campaigns/{id}/status")
    public CampaignDto setStatus(
            @PathVariable("id") long id,
            @RequestParam("status") CampaignStatus status,
            @Auth JwtPrincipal principal) {
        return campaigns.setStatus(principal.userId(), id, status);
    }
}
