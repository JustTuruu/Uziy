package mn.uziy.backend.viewer;

import static org.assertj.core.api.Assertions.assertThat;

import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.junit.jupiter.api.Test;

class QuestionMapperTest {

    private final QuestionMapper mapper = new QuestionMapper();

    private static SurveyQuestionEntity question(String optionsJson) {
        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setId(10L);
        q.setCampaignId(1L);
        q.setPosition(2);
        q.setPrompt("P");
        q.setQType("SINGLE_CHOICE");
        q.setOptionsJson(optionsJson);
        q.setRequired(true);
        return q;
    }

    @Test
    void mapsFieldsAndParsesOptions() {
        QuestionDto dto = mapper.toDto(question("[\"A\", \"B\"]"));
        assertThat(dto.id()).isEqualTo(10L);
        assertThat(dto.position()).isEqualTo(2);
        assertThat(dto.prompt()).isEqualTo("P");
        assertThat(dto.type()).isEqualTo("SINGLE_CHOICE");
        assertThat(dto.required()).isTrue();
        assertThat(dto.options()).containsExactly("A", "B");
    }

    @Test
    void emptyAndBlankOptionsYieldEmptyList() {
        assertThat(QuestionMapper.parseOptions("[]")).isEmpty();
        assertThat(QuestionMapper.parseOptions("")).isEmpty();
    }
}
