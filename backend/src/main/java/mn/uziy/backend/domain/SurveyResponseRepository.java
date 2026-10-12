package mn.uziy.backend.domain;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/** Survey answers. */
@Repository
public interface SurveyResponseRepository extends JpaRepository<SurveyResponseEntity, Long> {

    /**
     * Every answer given to one campaign's questions, with the answerer's gender and age so answers can be
     * compared across segments: rows of [question id, answer as JSON text, gender text or null, age in years or null].
     */
    @Query(value = """
        SELECT sr.question_id, CAST(sr.answer_json AS text), CAST(u.gender AS text),
               CAST(date_part('year', age(u.birth_date)) AS int)
        FROM survey_responses sr
        JOIN view_history v ON v.id = sr.view_id
        JOIN users u ON u.id = v.user_id
        WHERE v.campaign_id = :campaignId
    """, nativeQuery = true)
    List<Object[]> answersOfCampaign(@Param("campaignId") long campaignId);
}
