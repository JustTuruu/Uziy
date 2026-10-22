package mn.uziy.backend.trusteddevice;

import java.time.OffsetDateTime;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Remembered browsers. Every decision is one conditional statement, so no read-then-write race decides trust. */
public interface TrustedDeviceRepository extends JpaRepository<TrustedDeviceEntity, Long> {

    /**
     * Marks the browser with secret hash {@code hash} as used now, only when it belongs to {@code userId}, has not
     * run out, and was trusted after the account's password last changed (a reset or a deletion makes every older
     * browser a stranger again, even if a row were left behind). Returns 1 when the browser is trusted, else 0.
     */
    @Modifying(flushAutomatically = true)
    @Query(value = """
            UPDATE trusted_devices d SET last_used_at = :now
            FROM users u
            WHERE d.token_hash = :hash AND d.user_id = :userId AND u.id = d.user_id
              AND d.expires_at > :now
              AND (u.credentials_changed_at IS NULL OR d.created_at > u.credentials_changed_at)""",
            nativeQuery = true)
    int touchIfTrusted(@Param("hash") String hash, @Param("userId") long userId, @Param("now") OffsetDateTime now);

    /**
     * Keeps the {@code keep} browsers of {@code userId} used most recently and deletes the rest, together with any
     * that have run out. Returns how many were deleted.
     */
    @Modifying(flushAutomatically = true)
    @Query(value = """
            DELETE FROM trusted_devices
            WHERE user_id = :userId
              AND (expires_at <= :now OR id NOT IN (
                    SELECT id FROM trusted_devices
                    WHERE user_id = :userId AND expires_at > :now
                    ORDER BY last_used_at DESC, id DESC
                    LIMIT :keep))""", nativeQuery = true)
    int evictBeyond(@Param("userId") long userId, @Param("keep") int keep, @Param("now") OffsetDateTime now);

    /** Forgets every browser of {@code userId}. Returns how many there were. */
    @Modifying(flushAutomatically = true)
    @Query(value = "DELETE FROM trusted_devices WHERE user_id = :userId", nativeQuery = true)
    int deleteAllOfUser(@Param("userId") long userId);
}
