package mn.uziy.backend.phoneverify;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface PhoneVerificationRepository extends JpaRepository<PhoneVerificationEntity, UUID> {

    Optional<PhoneVerificationEntity> findFirstByPhoneNumberOrderByCreatedAtDesc(String phoneNumber);

    long countByPhoneNumberAndCreatedAtAfter(String phoneNumber, OffsetDateTime since);

    /**
     * Holds a Postgres advisory lock for {@code phoneNumber} until the caller's transaction ends, so starts for
     * one phone run one after another: the next one only reads the limits once the previous row is committed.
     * Different phones never wait for each other (a hash collision merely queues two of them). Returns 1.
     */
    @Query(value = "SELECT COUNT(*) FROM (SELECT pg_advisory_xact_lock(:namespace, hashtext(:phone))) AS l",
            nativeQuery = true)
    long lockPhone(@Param("namespace") int namespace, @Param("phone") String phoneNumber);

    /**
     * Marks a confirmed, unused check opened for {@code purpose} as used — in one conditional UPDATE, so two registrations racing with
     * the same id cannot both succeed. Returns 1 when this caller won, 0 otherwise.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            UPDATE PhoneVerificationEntity v SET v.claimed = true
            WHERE v.id = :id AND v.phoneNumber = :phone AND v.purpose = :purpose AND v.claimed = false
              AND v.status = mn.uziy.backend.phoneverify.PhoneVerificationStatus.VERIFIED
              AND v.verifiedAt > :verifiedAfter""")
    int tryClaim(@Param("id") UUID id, @Param("phone") String phoneNumber,
                 @Param("purpose") PhoneVerificationPurpose purpose,
                 @Param("verifiedAfter") OffsetDateTime verifiedAfter);
}
