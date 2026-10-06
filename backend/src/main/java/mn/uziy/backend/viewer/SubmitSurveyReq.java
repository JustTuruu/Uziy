package mn.uziy.backend.viewer;

import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record SubmitSurveyReq(@NotEmpty List<Answer> answers) {

    public record Answer(
            long questionId,
            /** Serialized JSON: "text", ["a","b"], "single choice" */
            String answerJson) {
    }
}
