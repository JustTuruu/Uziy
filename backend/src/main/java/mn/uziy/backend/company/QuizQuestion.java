package mn.uziy.backend.company;

import java.util.HashSet;
import java.util.List;
import mn.uziy.backend.common.BadRequestException;

/**
 * A QUIZ question checks that the viewer really watched: it asks about the video and has exactly one correct
 * option. The viewer may try again until they pick it (owner, 2026-10-30), so the reward is paid only for a
 * correct pick. Only a video campaign may ask one — without a video there is nothing to be right about.
 */
public final class QuizQuestion {

    public static final String TYPE = "QUIZ";
    public static final int MIN_OPTIONS = 2;

    public static final String NEEDS_VIDEO = "Зөв хариулттай асуулт зөвхөн видеотой судалгаанд байна";
    public static final String NEEDS_OPTIONS =
            "Зөв хариулттай асуултад дор хаяж " + MIN_OPTIONS + " өөр хариулт оруулна уу";
    public static final String NEEDS_CORRECT = "Зөв хариулттай асуултын зөв хариултыг сонгоно уу";

    private QuizQuestion() {
    }

    public static boolean isQuiz(String type) {
        return TYPE.equals(type);
    }

    /** @throws BadRequestException with one of the messages above */
    public static void check(boolean hasVideo, List<CreateCampaignReq.NewQuestion> questions) {
        for (CreateCampaignReq.NewQuestion q : questions) {
            if (isQuiz(q.type())) {
                checkOne(hasVideo, q);
            }
        }
    }

    private static void checkOne(boolean hasVideo, CreateCampaignReq.NewQuestion q) {
        if (!hasVideo) {
            throw new BadRequestException(NEEDS_VIDEO);
        }
        List<String> options = q.options();
        boolean blankOption = options.stream().anyMatch(String::isBlank);
        if (options.size() < MIN_OPTIONS || blankOption || new HashSet<>(options).size() != options.size()) {
            throw new BadRequestException(NEEDS_OPTIONS);
        }
        String correct = q.correctAnswer();
        if (correct == null || !options.contains(correct)) {
            throw new BadRequestException(NEEDS_CORRECT);
        }
    }
}
