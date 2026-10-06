package mn.uziy.backend.company;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import mn.uziy.backend.domain.TargetGender;
import org.jspecify.annotations.Nullable;

/**
 * Pricing inputs: {@code totalBudget} plus EXACTLY ONE of {@code targetViewers} (VIEWERS
 * mode) or {@code rewardPerUser} (REWARD mode). The server derives everything else
 * with the current platform commission — cost-per-view is never taken from
 * the client (an unknown {@code costPerView} field in the JSON is ignored).
 *
 * <p>Missing JSON fields get the same defaults the Kotlin data class had (see the compact
 * constructor); the component types are boxed so "absent" can be told apart from zero.
 *
 * @param hasVideo      set false for survey-only campaigns (videoUrl + durationSeconds ignored)
 * @param totalBudget   B, whole ₮. Nullable so a missing value gets the Mongolian pricing message
 * @param rewardPerUser R, whole ₮
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record CreateCampaignReq(
        @NotBlank String title,
        String videoUrl,
        Boolean hasVideo,
        Integer durationSeconds,
        TargetGender targetGender,
        Integer minAge,
        Integer maxAge,
        String targetCity,
        @Nullable Double totalBudget,
        @Nullable Integer targetViewers,
        @Nullable Double rewardPerUser,
        @Valid List<NewQuestion> questions) {

    public CreateCampaignReq {
        videoUrl = videoUrl == null ? "" : videoUrl;
        hasVideo = hasVideo == null || hasVideo;
        durationSeconds = durationSeconds == null ? 0 : durationSeconds;
        targetGender = targetGender == null ? TargetGender.ALL : targetGender;
        minAge = minAge == null ? 0 : minAge;
        maxAge = maxAge == null ? 100 : maxAge;
        targetCity = targetCity == null ? "ALL" : targetCity;
        questions = questions == null ? List.of() : List.copyOf(questions);
    }

    /** A request with only the required title and defaults everywhere else. */
    public static CreateCampaignReq of(String title) {
        return new CreateCampaignReq(title, null, null, null, null, null, null, null,
                null, null, null, null);
    }

    /**
     * @param type SINGLE_CHOICE | MULTI_CHOICE | TEXT
     */
    public record NewQuestion(
            @NotNull String prompt,
            @NotNull String type,
            List<String> options,
            Boolean required) {

        public NewQuestion {
            options = options == null ? List.of() : List.copyOf(options);
            required = required == null || required;
        }

        public NewQuestion(String prompt, String type) {
            this(prompt, type, null, null);
        }
    }
}
