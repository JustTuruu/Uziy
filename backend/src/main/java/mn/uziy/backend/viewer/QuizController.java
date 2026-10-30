package mn.uziy.backend.viewer;

import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter: {@code POST /viewer/campaigns/{id}/questions/{questionId}/check} → {@code {correct}}. */
@RestController
@RequestMapping("/viewer/campaigns")
@PreAuthorize("hasRole('VIEWER')")
public class QuizController {

    private final QuizCheckService quizzes;

    public QuizController(QuizCheckService quizzes) {
        this.quizzes = quizzes;
    }

    @PostMapping("/{id}/questions/{questionId}/check")
    public QuizCheckResult check(@PathVariable("id") long id,
                                 @PathVariable("questionId") long questionId,
                                 @Valid @RequestBody CheckQuizAnswerReq body) {
        return quizzes.check(id, questionId, body.answer());
    }
}
