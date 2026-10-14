package mn.uziy.backend.phoneverify;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

/** One provider session checking a phone number, before registration or a password reset. */
@Entity
@Table(name = "phone_verifications")
public class PhoneVerificationEntity {

    /** Random and unguessable: the app polls with it and sends it with the registration form. */
    @Id
    private UUID id = UUID.randomUUID();

    @Column(name = "phone_number", nullable = false)
    private String phoneNumber = "";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PhoneVerificationPurpose purpose = PhoneVerificationPurpose.REGISTER;

    @Column(name = "provider_session_id", nullable = false)
    private String providerSessionId = "";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PhoneVerificationStatus status = PhoneVerificationStatus.PENDING;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt = OffsetDateTime.now();

    @Column(name = "verified_at")
    private OffsetDateTime verifiedAt;

    @Column(nullable = false)
    private boolean claimed = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    public PhoneVerificationEntity() {
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }

    public PhoneVerificationPurpose getPurpose() { return purpose; }
    public void setPurpose(PhoneVerificationPurpose purpose) { this.purpose = purpose; }

    public String getProviderSessionId() { return providerSessionId; }
    public void setProviderSessionId(String providerSessionId) { this.providerSessionId = providerSessionId; }

    public PhoneVerificationStatus getStatus() { return status; }
    public void setStatus(PhoneVerificationStatus status) { this.status = status; }

    public OffsetDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(OffsetDateTime expiresAt) { this.expiresAt = expiresAt; }

    public @Nullable OffsetDateTime getVerifiedAt() { return verifiedAt; }
    public void setVerifiedAt(@Nullable OffsetDateTime verifiedAt) { this.verifiedAt = verifiedAt; }

    public boolean isClaimed() { return claimed; }
    public void setClaimed(boolean claimed) { this.claimed = claimed; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}
