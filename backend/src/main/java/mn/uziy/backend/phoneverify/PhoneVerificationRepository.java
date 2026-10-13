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
     * Marks a confirmed, unused check as used — in one conditional UPDATE, so two registrations racing with
     * the same id cannot both succeed. Returns 1 when this caller won, 0 otherwise.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            UPDATE PhoneVerificationEntity v SET v.claimed = true
            WHERE v.id = :id AND v.phoneNumber = :phone AND v.claimed = false
              AND v.status = mn.uziy.backend.phoneverify.PhoneVerificationStatus.VERIFIED
              AND v.verifiedAt > :verifiedAfter""")
    int tryClaim(@Param("id") UUID id, @Param("phone") String phoneNumber,
                 @Param("verifiedAfter") OffsetDateTime verifiedAfter);
}
