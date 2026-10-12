package mn.uziy.backend.company;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
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
        @NotBlank @Size(max = MAX_TITLE) String title,
        @Size(max = MAX_VIDEO_URL) String videoUrl,
        Boolean hasVideo,
        Integer durationSeconds,
        TargetGender targetGender,
        Integer minAge,
        Integer maxAge,
        @Size(max = MAX_CITY) String targetCity,
        @Nullable Double totalBudget,
        @Nullable Integer targetViewers,
        @Nullable Double rewardPerUser,
        @Size(max = MAX_QUESTIONS) @Valid List<NewQuestion> questions) {

    // These mirror the column sizes (and sane survey sizes), so an over-long value is a clear 400 and not a
    // database error.
    public static final int MAX_TITLE = 200;
    public static final int MAX_VIDEO_URL = 500;
    public static final int MAX_CITY = 50;
    public static final int MAX_QUESTIONS = 20;
    public static final int MAX_PROMPT = 1_000;
    public static final int MAX_OPTIONS = 20;
    public static final int MAX_OPTION_LENGTH = 200;

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
     * @param type SINGLE_CHOICE | MULTI_CHOICE | TEXT | RATING (options are ignored: {@link RatingScale})
     */
    public record NewQuestion(
            @NotNull @Size(max = MAX_PROMPT) String prompt,
            @NotNull @Size(max = 20) String type,
            @Size(max = MAX_OPTIONS) List<@Size(max = MAX_OPTION_LENGTH) String> options,
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
