package mn.uziy.backend.viewer;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Decides whether a submitted set of answers is a real response to a campaign's survey, before any
 * reward is paid: every answer belongs to one of the campaign's questions (once), is well-formed JSON of
 * the right shape and size, a choice answer picks only listed options, and every required question has
 * an answer. Anything else is a 400, never a half-recorded reward or a database error.
 */
@Component
public class AnswerValidator {

    public static final int MAX_ANSWER_LENGTH = 2_000;

    public static final String UNKNOWN_QUESTION = "Асуулт олдсонгүй";
    public static final String DUPLICATE_ANSWER = "Нэг асуултад хоёр хариулт өгөх боломжгүй";
    public static final String BAD_ANSWER = "Хариулт буруу байна";
    public static final String ANSWER_TOO_LONG = "Хариулт хэт урт байна";
    public static final String MISSING_ANSWER = "Бүх заавал хариулах асуултад хариулна уу";

    private static final String TEXT = "TEXT";
    private static final String SINGLE_CHOICE = "SINGLE_CHOICE";
    private static final String MULTI_CHOICE = "MULTI_CHOICE";
    private static final String RATING = "RATING";

    private static final JsonMapper JSON = JsonMapper.builder().build();

    public void validate(List<SurveyQuestionEntity> questions, List<SubmitSurveyReq.Answer> answers) {
        Map<Long, SurveyQuestionEntity> byId = questions.stream()
                .collect(Collectors.toMap(SurveyQuestionEntity::getId, q -> q));
        Set<Long> seen = new HashSet<>();
        Set<Long> answeredWithContent = new HashSet<>();

        for (SubmitSurveyReq.Answer a : answers) {
            SurveyQuestionEntity q = byId.get(a.questionId());
            if (q == null) {
                throw new BadRequestException(UNKNOWN_QUESTION);
            }
            if (!seen.add(q.getId())) {
                throw new BadRequestException(DUPLICATE_ANSWER);
            }
            if (isBlank(a.answerJson())) {
                continue; // left empty: only a problem when the question is required (checked below)
            }
            if (a.answerJson().length() > MAX_ANSWER_LENGTH) {
                throw new BadRequestException(ANSWER_TOO_LONG);
            }
            JsonNode value = parse(a.answerJson());
            checkShape(q, value);
            if (!isEmptyAnswer(value)) {
                answeredWithContent.add(q.getId());
            }
        }

        for (SurveyQuestionEntity q : questions) {
            if (q.isRequired() && !answeredWithContent.contains(q.getId())) {
                throw new BadRequestException(MISSING_ANSWER);
            }
        }
    }

    private static boolean isBlank(String json) {
        return json == null || json.isBlank();
    }

    private static JsonNode parse(String json) {
        try {
            return JSON.readTree(json);
        } catch (RuntimeException e) {
            throw new BadRequestException(BAD_ANSWER);
        }
    }

    private static boolean isEmptyAnswer(JsonNode node) {
        return (node.isString() && node.asString().isBlank()) || (node.isArray() && node.isEmpty());
    }

    private static void checkShape(SurveyQuestionEntity q, JsonNode node) {
        switch (q.getQType()) {
            case TEXT -> require(node.isString());
            // A rating is one pick from its stored scale, like a single choice.
            case SINGLE_CHOICE, RATING -> {
                require(node.isString());
                require(node.asString().isEmpty() || optionsOf(q).contains(node.asString()));
            }
            case MULTI_CHOICE -> {
                require(node.isArray());
                Set<String> options = optionsOf(q);
                for (JsonNode item : node) {
                    require(item.isString() && options.contains(item.asString()));
                }
            }
            default -> throw new BadRequestException(BAD_ANSWER);
        }
    }

    private static Set<String> optionsOf(SurveyQuestionEntity q) {
        Set<String> options = new HashSet<>();
        try {
            for (JsonNode item : JSON.readTree(q.getOptionsJson())) {
                if (item.isString()) {
                    options.add(item.asString());
                }
            }
        } catch (RuntimeException ignored) {
            // an unreadable stored option list simply accepts no choice
        }
        return options;
    }

    private static void require(boolean ok) {
        if (!ok) {
            throw new BadRequestException(BAD_ANSWER);
        }
    }
}
