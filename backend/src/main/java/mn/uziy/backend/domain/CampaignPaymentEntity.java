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

/**
 * One row per payment attempt for a campaign. A campaign can have at most
 * one PAID row — enforced by the partial unique index
 * {@code ux_campaign_payments_one_paid} (V5) as a backstop behind the conditional
 * status UPDATE in {@link CampaignRepository#tryMarkPaid}.
 */
@Entity
@Table(name = "campaign_payments")
public class CampaignPaymentEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "campaign_id", nullable = false)
    private long campaignId = 0;

    @Column(name = "company_id", nullable = false)
    private long companyId = 0;

    /** Whole ₮ charged — equals the campaign's total_budget (= payable P). */
    @Column(nullable = false)
    private double amount = 0.0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentProvider provider = PaymentProvider.SIMULATED;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentStatus status = PaymentStatus.PAID;

    /** Human-facing invoice number, e.g. UZ-20260928-42. Unique. */
    @Column(nullable = false, length = 40, unique = true)
    private String reference = "";

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "paid_at")
    private OffsetDateTime paidAt;

    public CampaignPaymentEntity() {
    }

    public @Nullable Long getId() { return id; }
    public void setId(@Nullable Long id) { this.id = id; }

    public long getCampaignId() { return campaignId; }
    public void setCampaignId(long campaignId) { this.campaignId = campaignId; }

    public long getCompanyId() { return companyId; }
    public void setCompanyId(long companyId) { this.companyId = companyId; }

    public double getAmount() { return amount; }
    public void setAmount(double amount) { this.amount = amount; }

    public PaymentProvider getProvider() { return provider; }
    public void setProvider(PaymentProvider provider) { this.provider = provider; }

    public PaymentStatus getStatus() { return status; }
    public void setStatus(PaymentStatus status) { this.status = status; }

    public String getReference() { return reference; }
    public void setReference(String reference) { this.reference = reference; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }

    public @Nullable OffsetDateTime getPaidAt() { return paidAt; }
    public void setPaidAt(@Nullable OffsetDateTime paidAt) { this.paidAt = paidAt; }
}
