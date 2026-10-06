package mn.uziy.backend.domain;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/** Completed views; (user, campaign) is unique, which blocks double rewards. */
@Repository
public interface ViewHistoryRepository extends JpaRepository<ViewHistoryEntity, Long> {
    boolean existsByUserIdAndCampaignId(long userId, long campaignId);

    long countByCampaignId(long campaignId);
}
