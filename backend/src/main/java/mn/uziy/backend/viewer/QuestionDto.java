package mn.uziy.backend.viewer;

import java.util.List;

public record QuestionDto(
        long id,
        int position,
        String prompt,
        String type,
        List<String> options,
        boolean required) {
}
