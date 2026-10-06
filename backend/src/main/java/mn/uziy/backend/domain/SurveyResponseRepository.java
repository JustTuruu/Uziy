package mn.uziy.backend.domain;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/** Survey answers. */
@Repository
public interface SurveyResponseRepository extends JpaRepository<SurveyResponseEntity, Long> {
    List<SurveyResponseEntity> findAllByQuestionId(long questionId);
}
