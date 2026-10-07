package mn.uziy.backend.otp;

import java.time.OffsetDateTime;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface OtpCodeRepository extends JpaRepository<OtpCodeEntity, Long> {

    /** The most recently issued code — the only one that can still be redeemed. */
    Optional<OtpCodeEntity> findFirstByPhoneNumberAndPurposeOrderByCreatedAtDesc(
            String phoneNumber, OtpPurpose purpose);

    long countByPhoneNumberAndPurposeAndCreatedAtAfter(
            String phoneNumber, OtpPurpose purpose, OffsetDateTime since);
}
