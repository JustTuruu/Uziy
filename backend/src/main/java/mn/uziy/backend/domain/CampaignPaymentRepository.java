package mn.uziy.backend.domain;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/** Campaign payment attempts. */
@Repository
public interface CampaignPaymentRepository extends JpaRepository<CampaignPaymentEntity, Long> {
    /** A company's payments, newest first (id breaks same-instant ties). */
    List<CampaignPaymentEntity> findAllByCompanyIdOrderByCreatedAtDescIdDesc(long companyId);
}
