package mn.uziy.backend.domain;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/** Completed views; (user, campaign) is unique, which blocks double rewards. */
@Repository
public interface ViewHistoryRepository extends JpaRepository<ViewHistoryEntity, Long> {
    boolean existsByUserIdAndCampaignId(long userId, long campaignId);

    long countByCampaignId(long campaignId);

    /** A viewer's most recent completed views, newest first; the caller bounds the size with {@code limit}. */
    List<ViewHistoryEntity> findByUserIdOrderByWatchedAtDesc(long userId, Pageable limit);
}
