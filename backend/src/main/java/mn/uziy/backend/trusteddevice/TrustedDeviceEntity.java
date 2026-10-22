package mn.uziy.backend.trusteddevice;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/**
 * A browser a console account (admin or company) proved its phone from, remembered for
 * {@link TrustedDeviceServiceImpl#TRUST_PERIOD}. Only the SHA-256 of the browser's secret is stored, so a copy of
 * this table cannot sign anybody in.
 */
@Entity
@Table(name = "trusted_devices")
public class TrustedDeviceEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private long userId;

    @Column(name = "token_hash", nullable = false, unique = true, updatable = false, length = 64)
    private String tokenHash = "";

    /** The browser family ("Chrome", "Safari", …) or null; never the full User-Agent. */
    @Column(length = 40, updatable = false)
    private @Nullable String label;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "expires_at", nullable = false, updatable = false)
    private OffsetDateTime expiresAt = OffsetDateTime.now();

    @Column(name = "last_used_at", nullable = false)
    private OffsetDateTime lastUsedAt = OffsetDateTime.now();

    public TrustedDeviceEntity() {
    }

    public @Nullable Long getId() { return id; }
    public void setId(@Nullable Long id) { this.id = id; }

    public long getUserId() { return userId; }
    public void setUserId(long userId) { this.userId = userId; }

    public String getTokenHash() { return tokenHash; }
    public void setTokenHash(String tokenHash) { this.tokenHash = tokenHash; }

    public @Nullable String getLabel() { return label; }
    public void setLabel(@Nullable String label) { this.label = label; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }

    public OffsetDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(OffsetDateTime expiresAt) { this.expiresAt = expiresAt; }

    public OffsetDateTime getLastUsedAt() { return lastUsedAt; }
    public void setLastUsedAt(OffsetDateTime lastUsedAt) { this.lastUsedAt = lastUsedAt; }
}
