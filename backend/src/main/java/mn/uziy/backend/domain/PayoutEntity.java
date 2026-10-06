package mn.uziy.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/** A viewer's cash-out request, reviewed by an admin (anti-fraud gate, spec §4A). */
@Entity
@Table(name = "payout_requests")
public class PayoutEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private long userId = 0;

    @Column(nullable = false)
    private double amount = 0.0;

    @Column(nullable = false, length = 60)
    private String bank = "";

    @Column(name = "account_number", nullable = false, length = 30)
    private String accountNumber = "";

    @Column(name = "account_name", nullable = false, length = 120)
    private String accountName = "";

    @Column(name = "national_id", nullable = false, length = 20)
    private String nationalId = "";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PayoutStatus status = PayoutStatus.PENDING;

    @Column(name = "is_first_payout", nullable = false)
    private boolean firstPayout = false;

    @Column(name = "reject_reason", length = 500)
    private String rejectReason;

    @Column(name = "decided_by")
    private Long decidedBy;

    @Column(name = "requested_at", nullable = false, updatable = false)
    private OffsetDateTime requestedAt = OffsetDateTime.now();

    @Column(name = "decided_at")
    private OffsetDateTime decidedAt;

    public PayoutEntity() {
    }

    public @Nullable Long getId() { return id; }
    public void setId(@Nullable Long id) { this.id = id; }

    public long getUserId() { return userId; }
    public void setUserId(long userId) { this.userId = userId; }

    public double getAmount() { return amount; }
    public void setAmount(double amount) { this.amount = amount; }

    public String getBank() { return bank; }
    public void setBank(String bank) { this.bank = bank; }

    public String getAccountNumber() { return accountNumber; }
    public void setAccountNumber(String accountNumber) { this.accountNumber = accountNumber; }

    public String getAccountName() { return accountName; }
    public void setAccountName(String accountName) { this.accountName = accountName; }

    public String getNationalId() { return nationalId; }
    public void setNationalId(String nationalId) { this.nationalId = nationalId; }

    public PayoutStatus getStatus() { return status; }
    public void setStatus(PayoutStatus status) { this.status = status; }

    public boolean isFirstPayout() { return firstPayout; }
    public void setFirstPayout(boolean firstPayout) { this.firstPayout = firstPayout; }

    public @Nullable String getRejectReason() { return rejectReason; }
    public void setRejectReason(@Nullable String rejectReason) { this.rejectReason = rejectReason; }

    public @Nullable Long getDecidedBy() { return decidedBy; }
    public void setDecidedBy(@Nullable Long decidedBy) { this.decidedBy = decidedBy; }

    public OffsetDateTime getRequestedAt() { return requestedAt; }
    public void setRequestedAt(OffsetDateTime requestedAt) { this.requestedAt = requestedAt; }

    public @Nullable OffsetDateTime getDecidedAt() { return decidedAt; }
    public void setDecidedAt(@Nullable OffsetDateTime decidedAt) { this.decidedAt = decidedAt; }
}
