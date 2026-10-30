package mn.uziy.backend.viewer;

import static mn.uziy.backend.common.FieldMessages.ANSWER_REQUIRED;
import static mn.uziy.backend.common.FieldMessages.OPTION_TOO_LONG;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import mn.uziy.backend.company.CreateCampaignReq;

/** The option a viewer picked on a QUIZ question, sent before the survey is submitted. */
public record CheckQuizAnswerReq(
        @NotNull(message = ANSWER_REQUIRED)
        @Size(max = CreateCampaignReq.MAX_OPTION_LENGTH, message = OPTION_TOO_LONG) String answer) {
}
