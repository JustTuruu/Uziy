package mn.uziy.backend.domain;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/** Survey questions of campaigns. */
@Repository
public interface SurveyQuestionRepository extends JpaRepository<SurveyQuestionEntity, Long> {
    List<SurveyQuestionEntity> findAllByCampaignIdOrderByPosition(long campaignId);

    void deleteAllByCampaignId(long campaignId);
}
