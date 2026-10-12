package mn.uziy.backend.analytics;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.analytics.AnalyticsDtos.OptionBySegment;
import mn.uziy.backend.analytics.AnalyticsDtos.SegmentBreakdown;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.junit.jupiter.api.Test;

class SegmentCounterTest {

    private static final int MIN = 5;

    private final SegmentCounter counter = new SegmentCounter();

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

    private static Object[] row(long question, String answerJson, String gender, Integer age) {
        return new Object[] {question, answerJson, gender, age};
    }

    /** {@code n} identical answers. */
    private static List<Object[]> many(int n, long question, String answerJson, String gender, Integer age) {
        List<Object[]> rows = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            rows.add(row(question, answerJson, gender, age));
        }
        return rows;
    }

    private static List<Object[]> concat(List<Object[]> a, List<Object[]> b) {
        List<Object[]> all = new ArrayList<>(a);
        all.addAll(b);
        return all;
    }

    @Test
    void countsWhatEachGenderAndAgeBandChose() {
        var q = question(1, "SINGLE_CHOICE", "[\"Yes\",\"No\"]");
        // 5 men aged 20 said Yes, 5 women aged 30 said No
        var rows = concat(many(5, 1, "\"Yes\"", "MALE", 20), many(5, 1, "\"No\"", "FEMALE", 30));

        SegmentBreakdown out = counter.count(List.of(q), rows, MIN).get(0);

        assertThat(out.segments()).containsExactly(
                new Slice("MALE", 5), new Slice("FEMALE", 5), new Slice("18–24", 5), new Slice("25–34", 5));
        assertThat(out.options()).containsExactly(
                new OptionBySegment("Yes", List.of(5L, 0L, 5L, 0L)),
                new OptionBySegment("No", List.of(0L, 5L, 0L, 5L)));
    }

    @Test
    void aSegmentBelowTheMinimumIsLeftOutEntirely() {
        var q = question(1, "SINGLE_CHOICE", "[\"Yes\"]");
        // 5 men aged 20, but only 4 women aged 20
        var rows = concat(many(5, 1, "\"Yes\"", "MALE", 20), many(4, 1, "\"Yes\"", "FEMALE", 20));

        SegmentBreakdown out = counter.count(List.of(q), rows, MIN).get(0);

        assertThat(out.segments()).containsExactly(new Slice("MALE", 5), new Slice("18–24", 9));
    }

    @Test
    void aQuestionWhereNoSegmentIsBigEnoughIsDropped() {
        var q = question(1, "SINGLE_CHOICE", "[\"Yes\"]");

        assertThat(counter.count(List.of(q), many(4, 1, "\"Yes\"", "MALE", 20), MIN)).isEmpty();
    }

    @Test
    void freeTextQuestionsAreNeverBrokenDown() {
        var q = question(1, "TEXT", "[]");

        assertThat(counter.count(List.of(q), many(10, 1, "\"hi\"", "MALE", 20), MIN)).isEmpty();
    }

    @Test
    void multiChoicePicksAreCountedPerOption() {
        var q = question(1, "MULTI_CHOICE", "[\"A\",\"B\"]");
        var rows = concat(many(3, 1, "[\"A\",\"B\"]", "MALE", null), many(2, 1, "[\"A\"]", "MALE", null));

        SegmentBreakdown out = counter.count(List.of(q), rows, MIN).get(0);

        assertThat(out.segments()).containsExactly(new Slice("MALE", 5));
        assertThat(out.options()).containsExactly(
                new OptionBySegment("A", List.of(5L)), new OptionBySegment("B", List.of(3L)));
    }

    @Test
    void respondentsWithAnUnknownGenderOrAgeStillCountInTheOtherSegment() {
        var q = question(1, "SINGLE_CHOICE", "[\"Yes\"]");
        var rows = concat(many(5, 1, "\"Yes\"", null, 40), many(1, 1, "\"Yes\"", "MALE", null));

        SegmentBreakdown out = counter.count(List.of(q), rows, MIN).get(0);

        assertThat(out.segments()).containsExactly(new Slice("35–44", 5));
    }

    @Test
    void answersStayWithTheirOwnQuestion() {
        var q1 = question(1, "SINGLE_CHOICE", "[\"Yes\"]");
        var q2 = question(2, "SINGLE_CHOICE", "[\"Yes\"]");

        List<SegmentBreakdown> out = counter.count(List.of(q1, q2), many(5, 2, "\"Yes\"", "MALE", 20), MIN);

        assertThat(out).hasSize(1);
        assertThat(out.get(0).questionId()).isEqualTo(2);
    }
}
