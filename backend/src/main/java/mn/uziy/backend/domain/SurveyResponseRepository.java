package mn.uziy.backend.domain;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/** Survey answers. */
@Repository
public interface SurveyResponseRepository extends JpaRepository<SurveyResponseEntity, Long> {
}
