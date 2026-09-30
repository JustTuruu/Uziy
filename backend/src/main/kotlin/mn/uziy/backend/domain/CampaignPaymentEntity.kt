package mn.uziy.backend.domain

import jakarta.persistence.*
import java.time.OffsetDateTime

/** SIMULATED = the test "Төлөх" button; QPAY / BANK_TRANSFER are reserved for real gateways. */
enum class PaymentProvider { SIMULATED, QPAY, BANK_TRANSFER }
enum class PaymentStatus { PAID, FAILED, REFUNDED }

/**
 * One row per payment attempt for a campaign. A campaign can have at most
 * one PAID row — enforced by the partial unique index
 * `ux_campaign_payments_one_paid` (V5) as a backstop behind the conditional
 * status UPDATE in [CampaignRepository.tryMarkPaid].
 */
@Entity
@Table(name = "campaign_payments")
class CampaignPaymentEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(name = "campaign_id", nullable = false)
    var campaignId: Long = 0,

    @Column(name = "company_id", nullable = false)
    var companyId: Long = 0,

    /** Whole ₮ charged — equals the campaign's total_budget (= payable P). */
    @Column(nullable = false)
    var amount: Double = 0.0,

    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    var provider: PaymentProvider = PaymentProvider.SIMULATED,

    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    var status: PaymentStatus = PaymentStatus.PAID,

    /** Human-facing invoice number, e.g. UZ-20260928-42. Unique. */
    @Column(nullable = false, length = 40, unique = true)
    var reference: String = "",

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now(),

    @Column(name = "paid_at")
    var paidAt: OffsetDateTime? = null,
)
