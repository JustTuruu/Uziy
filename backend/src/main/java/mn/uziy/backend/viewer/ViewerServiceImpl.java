package mn.uziy.backend.viewer;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class ViewerServiceImpl implements ViewerService {

    private final UserRepository users;
    private final CampaignRepository campaigns;
    private final SurveyQuestionRepository questions;

    public ViewerServiceImpl(UserRepository users, CampaignRepository campaigns,
                             SurveyQuestionRepository questions) {
        this.users = users;
        this.campaigns = campaigns;
        this.questions = questions;
    }

    @Override
    public Me me(long userId) {
        return Me.of(users.findById(userId).orElseThrow());
    }

    @Override
    public List<FeedItemDto> feed(long userId) {
        UserEntity user = users.findById(userId).orElseThrow();
        if (user.getGender() == null || user.getAge() == null || user.getCity() == null) {
            return List.of();
        }

        List<CampaignEntity> list = campaigns.findFeedFor(
                user.getId(),
                TargetGender.valueOf(user.getGender().name()),
                user.getAge(),
                user.getCity());
        List<Long> companyIds = list.stream().map(CampaignEntity::getCompanyId).distinct().toList();
        Map<Long, String> companyNames = new HashMap<>();
        for (UserEntity company : users.findAllById(companyIds)) {
            companyNames.put(company.getId(), company.getCompanyName() != null ? company.getCompanyName() : "");
        }
        return list.stream()
                .map(c -> new FeedItemDto(
                        c.getId(),
                        c.getTitle(),
                        c.getVideoUrl(),
                        c.getThumbnailUrl(),
                        c.getDurationSeconds(),
                        c.hasVideo(),
                        c.getRewardPerUser(),
                        companyNames.getOrDefault(c.getCompanyId(), "")))
                .toList();
    }

    @Override
    public List<QuestionDto> questions(long campaignId) {
        return questions.findAllByCampaignIdOrderByPosition(campaignId).stream()
                .map(q -> new QuestionDto(
                        q.getId(),
                        q.getPosition(),
                        q.getPrompt(),
                        q.getQType(),
                        parseOptions(q.getOptionsJson()),
                        q.isRequired()))
                .toList();
    }

    /** Cheap parser sufficient for a JSONB array of strings. */
    private static List<String> parseOptions(String json) {
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
