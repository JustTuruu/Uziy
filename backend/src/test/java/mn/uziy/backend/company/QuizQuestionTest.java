package mn.uziy.backend.company;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import mn.uziy.backend.common.BadRequestException;
import org.junit.jupiter.api.Test;

class QuizQuestionTest {

    private static CreateCampaignReq.NewQuestion quiz(List<String> options, String correct) {
        return new CreateCampaignReq.NewQuestion("Видеонд ямар өнгийн машин гарсан бэ?", QuizQuestion.TYPE,
                options, true, correct);
    }

    private static void refuses(String message, boolean hasVideo, CreateCampaignReq.NewQuestion q) {
        assertThatThrownBy(() -> QuizQuestion.check(hasVideo, List.of(q)))
                .isInstanceOf(BadRequestException.class).hasMessage(message);
    }

    @Test
    void aQuizWithAListedCorrectOptionOnAVideoCampaignIsAccepted() {
        assertThatCode(() -> QuizQuestion.check(true, List.of(quiz(List.of("Улаан", "Цэнхэр"), "Цэнхэр"))))
                .doesNotThrowAnyException();
    }

    @Test
    void aSurveyOnlyCampaignCannotAskAQuiz() {
        refuses(QuizQuestion.NEEDS_VIDEO, false, quiz(List.of("Улаан", "Цэнхэр"), "Улаан"));
    }

    @Test
    void aQuizNeedsTwoDistinctNonBlankOptions() {
        refuses(QuizQuestion.NEEDS_OPTIONS, true, quiz(List.of("Улаан"), "Улаан"));
        refuses(QuizQuestion.NEEDS_OPTIONS, true, quiz(List.of("Улаан", "Улаан"), "Улаан"));
        refuses(QuizQuestion.NEEDS_OPTIONS, true, quiz(List.of("Улаан", " "), "Улаан"));
    }

    @Test
    void theCorrectAnswerMustBeOneOfTheOptions() {
        refuses(QuizQuestion.NEEDS_CORRECT, true, quiz(List.of("Улаан", "Цэнхэр"), null));
        refuses(QuizQuestion.NEEDS_CORRECT, true, quiz(List.of("Улаан", "Цэнхэр"), "Ногоон"));
    }

    @Test
    void otherQuestionTypesAreNotChecked() {
        var single = new CreateCampaignReq.NewQuestion("Тийм үү?", "SINGLE_CHOICE", List.of("Тийм"), true);
        assertThatCode(() -> QuizQuestion.check(false, List.of(single))).doesNotThrowAnyException();
    }
}
