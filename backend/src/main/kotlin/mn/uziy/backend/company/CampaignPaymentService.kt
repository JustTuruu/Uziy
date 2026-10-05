package mn.uziy.backend.company

import mn.uziy.backend.common.ConflictException
import mn.uziy.backend.common.UnavailableException
import mn.uziy.backend.company.CompanyMessages.NOT_PAYABLE_MESSAGE
import mn.uziy.backend.company.CompanyMessages.PAYMENTS_UNAVAILABLE_MESSAGE
import mn.uziy.backend.domain.*
import mn.uziy.backend.payment.ChargeRequest
import mn.uziy.backend.payment.PaymentGateway
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

/** Paying for campaigns, and the company's payment history. */
interface CampaignPaymentService {
    /**
     * Pay for one campaign (AWAITING_PAYMENT → PENDING, i.e. into the admin
     * moderation queue) through whichever [PaymentGateway] is available.
     *
     * Race safety: the status flip is a conditional UPDATE (0 rows → conflict),
     * and the partial unique index ux_campaign_payments_one_paid backs it up.
     */
    fun pay(companyId: Long, campaignId: Long): PayCampaignResponse

    /** The company's campaign payments, newest first. */
    fun list(companyId: Long): List<PaymentDto>
}

@Service
class CampaignPaymentServiceImpl(
    private val campaigns: CampaignRepository,
    private val payments: CampaignPaymentRepository,
    private val gateways: List<PaymentGateway>,
) : CampaignPaymentService {

    @Transactional
    override fun pay(companyId: Long, campaignId: Long): PayCampaignResponse {
        val c = campaigns.owned(companyId, campaignId)
        if (c.status != CampaignStatus.AWAITING_PAYMENT) throw ConflictException(NOT_PAYABLE_MESSAGE)
        val gateway = gateways.firstOrNull { it.isAvailable() }
            ?: throw UnavailableException(PAYMENTS_UNAVAILABLE_MESSAGE)

        val paidAt = CampaignServiceImpl.now()
        if (campaigns.tryMarkPaid(campaignId, paidAt) == 0) throw ConflictException(NOT_PAYABLE_MESSAGE)

        val charge = gateway.charge(ChargeRequest(
            campaignId = campaignId, companyId = c.companyId, amount = c.totalBudget, at = paidAt,
        ))
        val payment = try {
            payments.saveAndFlush(CampaignPaymentEntity(
                campaignId = campaignId,
                companyId  = c.companyId,
                amount     = c.totalBudget,
                provider   = gateway.provider,
                status     = PaymentStatus.PAID,
                reference  = charge.reference,
                createdAt  = paidAt,
                paidAt     = paidAt,
            ))
        } catch (_: DataIntegrityViolationException) {
            // Another PAID row already exists — the whole tx rolls back.
            throw ConflictException(NOT_PAYABLE_MESSAGE)
        }

        // `c` was detached by tryMarkPaid (clearAutomatically), so these
        // assignments only shape the response — they are not written back.
        c.status = CampaignStatus.PENDING
        c.paidAt = paidAt
        c.updatedAt = paidAt
        return PayCampaignResponse(
            campaign = CampaignDto.of(c),
            payment  = PaymentDto.of(payment, c.title),
        )
    }

    override fun list(companyId: Long): List<PaymentDto> {
        val list = payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(companyId)
        val titles = campaigns.findAllById(list.map { it.campaignId }.distinct())
            .associate { it.id!! to it.title }
        return list.map { PaymentDto.of(it, titles[it.campaignId] ?: "") }
    }
}
