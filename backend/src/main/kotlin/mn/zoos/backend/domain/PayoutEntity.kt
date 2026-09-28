package mn.zoos.backend.domain

import jakarta.persistence.*
import java.time.OffsetDateTime

enum class PayoutStatus { PENDING, APPROVED, REJECTED }

@Entity
@Table(name = "payout_requests")
class PayoutEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(name = "user_id", nullable = false)
    var userId: Long = 0,

    @Column(nullable = false)
    var amount: Double = 0.0,

    @Column(nullable = false, length = 60)
    var bank: String = "",

    @Column(name = "account_number", nullable = false, length = 30)
    var accountNumber: String = "",

    @Column(name = "account_name", nullable = false, length = 120)
    var accountName: String = "",

    @Column(name = "national_id", nullable = false, length = 20)
    var nationalId: String = "",

    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    var status: PayoutStatus = PayoutStatus.PENDING,

    @Column(name = "is_first_payout", nullable = false)
    var isFirstPayout: Boolean = false,

    @Column(name = "reject_reason", length = 500)
    var rejectReason: String? = null,

    @Column(name = "decided_by")
    var decidedBy: Long? = null,

    @Column(name = "requested_at", nullable = false, updatable = false)
    var requestedAt: OffsetDateTime = OffsetDateTime.now(),

    @Column(name = "decided_at")
    var decidedAt: OffsetDateTime? = null,
)
