package mn.uziy.backend.viewer;

import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** Pattern: Mapper — survey question entity to {@link QuestionDto}, parsing the JSONB options. */
@Component
public class QuestionMapper {

    private static final JsonMapper JSON = JsonMapper.builder().build();

    public QuestionDto toDto(SurveyQuestionEntity q) {
        return new QuestionDto(
                q.getId(),
                q.getPosition(),
                q.getPrompt(),
                q.getQType(),
                parseOptions(q.getOptionsJson()),
                q.isRequired());
    }

    /**
     * The strings of a JSON array. A real JSON parse, not a split on commas: an option such as
     * "10,000₮-аас бага" or "Тийм, сүүлийн сард" must stay one option, and an escaped quote must survive.
     */
    static List<String> parseOptions(String json) {
        try {
            List<String> options = new ArrayList<>();
            for (JsonNode item : JSON.readTree(json)) {
                if (item.isString() && !item.asString().isBlank()) {
                    options.add(item.asString());
                }
            }
            return options;
        } catch (RuntimeException e) {
            return List.of();
        }
    }
}
