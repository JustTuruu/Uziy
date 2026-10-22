package mn.uziy.backend.analytics;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import mn.uziy.backend.analytics.AnalyticsDtos.QuestionBreakdown;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.junit.jupiter.api.Test;

class AnswerCounterTest {

    /** The counting tests below are about what is counted, not about hiding small groups. */
    private static final int NO_MINIMUM = 0;
    private static final int MIN = 5;

    private final AnswerCounter counter = new AnswerCounter();

    private List<QuestionBreakdown> count(List<SurveyQuestionEntity> questions, List<Object[]> answers) {
        return counter.count(questions, answers, NO_MINIMUM);
    }

    /** {@code n} copies of the same answer row. */
    private static List<Object[]> repeated(int n, Object[] row) {
        return java.util.Collections.nCopies(n, row);
    }

    private static SurveyQuestionEntity question(long id, String type, String optionsJson) {
        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setId(id);
        q.setCampaignId(1L);
        q.setPosition((int) id);
        q.setPrompt("q" + id);
        q.setQType(type);
        q.setOptionsJson(optionsJson);
        return q;
    }

    private static Object[] answer(long questionId, String json) {
        return new Object[] {questionId, json};
    }

    /** List.of(oneArray) would spread the array as varargs; this keeps each row a row. */
    private static List<Object[]> answers(Object[]... rows) {
        return java.util.Arrays.asList(rows);
    }

    @Test
    void singleChoiceCountsEachOptionKeepingTheQuestionsOrder() {
        var q = question(1, "SINGLE_CHOICE", "[\"Тийм\",\"Дунд зэрэг\",\"Үгүй\"]");

        QuestionBreakdown out = count(List.of(q), answers(
                answer(1, "\"Тийм\""), answer(1, "\"Тийм\""), answer(1, "\"Үгүй\""))).get(0);

        assertThat(out.answered()).isEqualTo(3);
        assertThat(out.options()).containsExactly(
                new Slice("Тийм", 2), new Slice("Дунд зэрэг", 0), new Slice("Үгүй", 1));
    }

    @Test
    void multiChoiceCountsEveryPickedOption() {
        var q = question(1, "MULTI_CHOICE", "[\"A\",\"B\",\"C\"]");

        QuestionBreakdown out = count(List.of(q), answers(
                answer(1, "[\"A\",\"B\"]"), answer(1, "[\"B\"]"))).get(0);

        assertThat(out.answered()).isEqualTo(2);
        assertThat(out.options()).containsExactly(new Slice("A", 1), new Slice("B", 2), new Slice("C", 0));
    }

    @Test
    void anOptionWithACommaIsCountedWhole() {
        var q = question(1, "SINGLE_CHOICE", "[\"Тийм, гэхдээ\",\"Үгүй\"]");

        QuestionBreakdown out = count(List.of(q), answers(answer(1, "\"Тийм, гэхдээ\""))).get(0);

        assertThat(out.options()).containsExactly(new Slice("Тийм, гэхдээ", 1), new Slice("Үгүй", 0));
    }

    @Test
    void freeTextIsCountedButHasNoOptions() {
        var q = question(1, "TEXT", "[]");

        QuestionBreakdown out = count(List.of(q), answers(answer(1, "\"сайн\""), answer(1, "\"муу\""))).get(0);

        assertThat(out.answered()).isEqualTo(2);
        assertThat(out.options()).isEmpty();
    }

    @Test
    void anAnswerNotAmongTheOptionsAddsToNoOption() {
        var q = question(1, "SINGLE_CHOICE", "[\"A\",\"B\"]");

        QuestionBreakdown out = count(List.of(q), answers(answer(1, "\"old option\""))).get(0);

        assertThat(out.answered()).isEqualTo(1);
        assertThat(out.options()).containsExactly(new Slice("A", 0), new Slice("B", 0));
    }

    @Test
    void unreadableAnswerJsonIsCountedAsAnsweredAndNothingElse() {
        var q = question(1, "SINGLE_CHOICE", "[\"A\"]");

        QuestionBreakdown out = count(List.of(q), answers(answer(1, "{not json"))).get(0);

        assertThat(out.answered()).isEqualTo(1);
        assertThat(out.options()).containsExactly(new Slice("A", 0));
    }

    @Test
    void aQuestionNobodyAnsweredStillAppearsWithZeros() {
        var q = question(1, "SINGLE_CHOICE", "[\"A\"]");

        QuestionBreakdown out = count(List.of(q), List.of()).get(0);

        assertThat(out.answered()).isZero();
        assertThat(out.options()).containsExactly(new Slice("A", 0));
    }

    @Test
    void answersAreMatchedToTheirOwnQuestion() {
        var q1 = question(1, "SINGLE_CHOICE", "[\"A\"]");
        var q2 = question(2, "SINGLE_CHOICE", "[\"A\"]");

        List<QuestionBreakdown> out = count(List.of(q1, q2), answers(answer(2, "\"A\"")));

        assertThat(out.get(0).options()).containsExactly(new Slice("A", 0));
        assertThat(out.get(1).options()).containsExactly(new Slice("A", 1));
    }

    // ------- the minimum -----------------------------------------------------

    @Test
    void belowTheMinimumOnlyTheAnswerCountIsShownNotWhatWasChosen() {
        var q = question(1, "SINGLE_CHOICE", "[\"Тийм\",\"Үгүй\"]");

        QuestionBreakdown out = counter.count(List.of(q), repeated(MIN - 1, answer(1, "\"Тийм\"")), MIN).get(0);

        assertThat(out.answered()).isEqualTo(MIN - 1);
        assertThat(out.options()).isEmpty();
    }

    @Test
    void atTheMinimumTheOptionsAreCounted() {
        var q = question(1, "SINGLE_CHOICE", "[\"Тийм\",\"Үгүй\"]");

        QuestionBreakdown out = counter.count(List.of(q), repeated(MIN, answer(1, "\"Тийм\"")), MIN).get(0);

        assertThat(out.options()).containsExactly(new Slice("Тийм", MIN), new Slice("Үгүй", 0));
    }

    @Test
    void theMinimumIsJudgedPerQuestion() {
        var big = question(1, "SINGLE_CHOICE", "[\"A\"]");
        var small = question(2, "SINGLE_CHOICE", "[\"A\"]");
        List<Object[]> rows = new java.util.ArrayList<>(repeated(MIN, answer(1, "\"A\"")));
        rows.add(answer(2, "\"A\""));

        List<QuestionBreakdown> out = counter.count(List.of(big, small), rows, MIN);

        assertThat(out.get(0).options()).containsExactly(new Slice("A", MIN));
        assertThat(out.get(1).answered()).isEqualTo(1);
        assertThat(out.get(1).options()).isEmpty();
    }
}
