package mn.uziy.backend.analytics;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.analytics.AnalyticsDtos.QuestionBreakdown;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Turns the raw JSONB answers of a campaign into per-question counts. A choice answer is
 * a JSON string ("Тийм") or an array of strings; anything unreadable counts as answered
 * but adds to no option. A question answered by fewer than the minimum shows only how many
 * answered, never what they chose: with a handful of answers each pick points at a person.
 */
@Component
public class AnswerCounter {

    static final String TEXT = "TEXT";

    private static final JsonMapper JSON = JsonMapper.builder().build();

    /**
     * @param answers rows of [question id, answer JSON text]
     * @param minAnswered fewest answers a question needs before its option counts are shown
     */
    public List<QuestionBreakdown> count(List<SurveyQuestionEntity> questions, List<Object[]> answers,
                                         int minAnswered) {
        Map<Long, List<String>> answersByQuestion = new LinkedHashMap<>();
        for (Object[] row : answers) {
            answersByQuestion.computeIfAbsent(((Number) row[0]).longValue(), k -> new ArrayList<>())
                    .add((String) row[1]);
        }
        List<QuestionBreakdown> out = new ArrayList<>();
        for (SurveyQuestionEntity q : questions) {
            List<String> given = answersByQuestion.getOrDefault(q.getId(), List.of());
            List<Slice> options = given.size() < minAnswered ? List.of() : optionCounts(q, given);
            out.add(new QuestionBreakdown(q.getId(), q.getPrompt(), q.getQType(), given.size(), options));
        }
        return out;
    }

    private List<Slice> optionCounts(SurveyQuestionEntity q, List<String> given) {
        if (TEXT.equals(q.getQType())) {
            return List.of();
        }
        Map<String, Long> counts = new LinkedHashMap<>();
        for (String option : strings(q.getOptionsJson())) {
            counts.put(option, 0L);
        }
        for (String answer : given) {
            for (String picked : strings(answer)) {
                counts.computeIfPresent(picked, (k, n) -> n + 1);
            }
        }
        List<Slice> out = new ArrayList<>();
        counts.forEach((label, n) -> out.add(new Slice(label, n)));
        return out;
    }

    /** The strings in a JSON string or array of strings; empty for anything else. */
    public static List<String> strings(String json) {
        try {
            JsonNode node = JSON.readTree(json);
            List<String> out = new ArrayList<>();
            if (node.isString()) {
                out.add(node.asString());
            } else if (node.isArray()) {
                for (JsonNode item : node) {
                    if (item.isString()) {
                        out.add(item.asString());
                    }
                }
            }
            return out;
        } catch (RuntimeException e) {
            return List.of();
        }
    }
}
