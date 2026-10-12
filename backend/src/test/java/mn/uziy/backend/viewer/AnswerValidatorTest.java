package mn.uziy.backend.viewer;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.junit.jupiter.api.Test;

class AnswerValidatorTest {

    private final AnswerValidator validator = new AnswerValidator();

    private static SurveyQuestionEntity q(long id, String type, String options, boolean required) {
        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setId(id);
        q.setCampaignId(1L);
        q.setPosition((int) id);
        q.setPrompt("p");
        q.setQType(type);
        q.setOptionsJson(options);
        q.setRequired(required);
        return q;
    }

    private static SubmitSurveyReq.Answer a(long id, String json) {
        return new SubmitSurveyReq.Answer(id, json);
    }

    private void accepts(List<SurveyQuestionEntity> questions, SubmitSurveyReq.Answer... answers) {
        assertThatCode(() -> validator.validate(questions, List.of(answers))).doesNotThrowAnyException();
    }

    private void refuses(String message, List<SurveyQuestionEntity> questions, SubmitSurveyReq.Answer... answers) {
        assertThatThrownBy(() -> validator.validate(questions, List.of(answers)))
                .isInstanceOf(BadRequestException.class).hasMessage(message);
    }

    private final List<SurveyQuestionEntity> single = List.of(q(1, "SINGLE_CHOICE", "[\"Yes\",\"No\"]", true));

    @Test
    void aListedSingleChoiceIsAccepted() {
        accepts(single, a(1, "\"Yes\""));
    }

    @Test
    void anUnlistedSingleChoiceIsRefused() {
        refuses(AnswerValidator.BAD_ANSWER, single, a(1, "\"Maybe\""));
    }

    @Test
    void aSingleChoiceMustBeAStringNotAnArrayOrNumber() {
        refuses(AnswerValidator.BAD_ANSWER, single, a(1, "[\"Yes\"]"));
        refuses(AnswerValidator.BAD_ANSWER, single, a(1, "1"));
        refuses(AnswerValidator.BAD_ANSWER, single, a(1, "{\"a\":1}"));
    }

    @Test
    void aRatingTakesOneLabelOfItsScale() {
        var rating = List.of(q(1, "RATING", "[\"Муу\",\"Дунд\",\"Сайн\"]", true));
        accepts(rating, a(1, "\"Сайн\""));
        refuses(AnswerValidator.BAD_ANSWER, rating, a(1, "\"Маш сайн\""));
        refuses(AnswerValidator.BAD_ANSWER, rating, a(1, "[\"Сайн\"]"));
        refuses(AnswerValidator.BAD_ANSWER, rating, a(1, "3"));
    }

    @Test
    void multiChoiceTakesAnArrayOfListedOptions() {
        var multi = List.of(q(1, "MULTI_CHOICE", "[\"A\",\"B\",\"C\"]", true));
        accepts(multi, a(1, "[\"A\",\"C\"]"));
        refuses(AnswerValidator.BAD_ANSWER, multi, a(1, "[\"A\",\"Z\"]"));
        refuses(AnswerValidator.BAD_ANSWER, multi, a(1, "\"A\""));
        refuses(AnswerValidator.BAD_ANSWER, multi, a(1, "[1,2]"));
    }

    @Test
    void anEmptyMultiChoiceCountsAsNoAnswer() {
        refuses(AnswerValidator.MISSING_ANSWER, List.of(q(1, "MULTI_CHOICE", "[\"A\"]", true)), a(1, "[]"));
    }

    @Test
    void freeTextTakesAnyStringButNotOtherShapes() {
        var text = List.of(q(1, "TEXT", "[]", true));
        accepts(text, a(1, "\"anything at all\""));
        refuses(AnswerValidator.BAD_ANSWER, text, a(1, "[\"a\"]"));
    }

    @Test
    void answerTextThatIsNotJsonIsRefusedNotPassedToTheDatabase() {
        var text = List.of(q(1, "TEXT", "[]", true));
        refuses(AnswerValidator.BAD_ANSWER, text, a(1, "{not json"));
        refuses(AnswerValidator.BAD_ANSWER, text, a(1, "undefined"));
        refuses(AnswerValidator.BAD_ANSWER, text, a(1, "\"unterminated"));
    }

    @Test
    void anOversizedAnswerIsRefused() {
        var text = List.of(q(1, "TEXT", "[]", true));
        refuses(AnswerValidator.ANSWER_TOO_LONG, text,
                a(1, "\"" + "x".repeat(AnswerValidator.MAX_ANSWER_LENGTH) + "\""));
    }

    @Test
    void anAnswerToAnotherCampaignsQuestionIsRefused() {
        refuses(AnswerValidator.UNKNOWN_QUESTION, single, a(1, "\"Yes\""), a(99, "\"Yes\""));
    }

    @Test
    void answeringTheSameQuestionTwiceIsRefused() {
        refuses(AnswerValidator.DUPLICATE_ANSWER, single, a(1, "\"Yes\""), a(1, "\"No\""));
    }

    @Test
    void everyRequiredQuestionNeedsARealAnswer() {
        var two = List.of(q(1, "TEXT", "[]", true), q(2, "TEXT", "[]", true));
        refuses(AnswerValidator.MISSING_ANSWER, two, a(1, "\"x\""));
        refuses(AnswerValidator.MISSING_ANSWER, two, a(1, "\"x\""), a(2, ""));
        refuses(AnswerValidator.MISSING_ANSWER, two, a(1, "\"x\""), a(2, "\"  \""));
        accepts(two, a(1, "\"x\""), a(2, "\"y\""));
    }

    @Test
    void anOptionalQuestionMayBeLeftOut() {
        var mixed = List.of(q(1, "TEXT", "[]", true), q(2, "TEXT", "[]", false));
        accepts(mixed, a(1, "\"x\""));
        accepts(mixed, a(1, "\"x\""), a(2, ""));
    }
}
