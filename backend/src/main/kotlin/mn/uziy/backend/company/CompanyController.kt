package mn.uziy.backend.company

import jakarta.validation.Valid
import mn.uziy.backend.domain.CampaignStatus
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*

/** HTTP adapter for the company console — behaviour lives in the two services. */
@RestController
@RequestMapping("/company")
@PreAuthorize("hasRole('COMPANY')")
class CompanyController(
    private val campaigns: CampaignService,
    private val payments: CampaignPaymentService,
) {

    @GetMapping("/campaigns")
    fun list(@Auth principal: JwtPrincipal): List<CampaignDto> = campaigns.list(principal.userId)

    @GetMapping("/campaigns/{id}")
    fun get(@PathVariable id: Long, @Auth principal: JwtPrincipal): CampaignDto =
        campaigns.get(principal.userId, id)

    @PostMapping("/campaigns")
    fun create(
        @Valid @RequestBody body: CreateCampaignReq,
        @Auth principal: JwtPrincipal,
    ): CampaignDto = campaigns.create(principal.userId, body)

    @PostMapping("/campaigns/{id}/pay")
    fun pay(@PathVariable id: Long, @Auth principal: JwtPrincipal): PayCampaignResponse =
        payments.pay(principal.userId, id)

    @GetMapping("/payments")
    fun payments(@Auth principal: JwtPrincipal): List<PaymentDto> =
        payments.list(principal.userId)

    @PatchMapping("/campaigns/{id}/status")
    fun setStatus(
        @PathVariable id: Long,
        @RequestParam status: CampaignStatus,
        @Auth principal: JwtPrincipal,
    ): CampaignDto = campaigns.setStatus(principal.userId, id, status)
}
