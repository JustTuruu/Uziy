package mn.uziy.backend.viewer;

import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — survey question entity to {@link QuestionDto}, parsing the JSONB options. */
@Component
public class QuestionMapper {

    public QuestionDto toDto(SurveyQuestionEntity q) {
        return new QuestionDto(
                q.getId(),
                q.getPosition(),
                q.getPrompt(),
                q.getQType(),
                parseOptions(q.getOptionsJson()),
                q.isRequired());
    }

    /** Cheap parser sufficient for a JSONB array of strings. */
    static List<String> parseOptions(String json) {
        try {
            String s = json.trim();
            if (s.startsWith("[")) {
                s = s.substring(1);
            }
            if (s.endsWith("]")) {
                s = s.substring(0, s.length() - 1);
            }
            List<String> options = new ArrayList<>();
            for (String part : s.split(",")) {
                String option = stripQuotes(part.trim());
                if (!option.isBlank()) {
                    options.add(option);
                }
            }
            return options;
        } catch (RuntimeException e) {
            return List.of();
        }
    }

    private static String stripQuotes(String s) {
        int start = 0;
        int end = s.length();
        while (start < end && s.charAt(start) == '"') {
            start++;
        }
        while (end > start && s.charAt(end - 1) == '"') {
            end--;
        }
        return s.substring(start, end);
    }
}
