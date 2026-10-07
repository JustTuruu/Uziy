package mn.uziy.backend.viewer;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.ViewHistoryEntity;
import mn.uziy.backend.domain.ViewHistoryRepository;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

@Service
public class ViewerServiceImpl implements ViewerService {

    private final UserRepository users;
    private final CampaignRepository campaigns;
    private final SurveyQuestionRepository questions;
    private final ViewHistoryRepository views;

    private final MeMapper meMapper;
    private final FeedItemMapper feedMapper;
    private final QuestionMapper questionMapper;
    private final ViewHistoryMapper historyMapper;

    public ViewerServiceImpl(UserRepository users, CampaignRepository campaigns,
                             SurveyQuestionRepository questions, ViewHistoryRepository views,
                             MeMapper meMapper, FeedItemMapper feedMapper,
                             QuestionMapper questionMapper, ViewHistoryMapper historyMapper) {
        this.views = views;
        this.historyMapper = historyMapper;
        this.meMapper = meMapper;
        this.feedMapper = feedMapper;
        this.questionMapper = questionMapper;
        this.users = users;
        this.campaigns = campaigns;
        this.questions = questions;
    }

    @Override
    public Me me(long userId) {
        return meMapper.toMe(users.findById(userId).orElseThrow());
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
                .map(c -> feedMapper.toDto(c, companyNames.getOrDefault(c.getCompanyId(), "")))
                .toList();
    }

    @Override
    public List<QuestionDto> questions(long campaignId) {
        return questions.findAllByCampaignIdOrderByPosition(campaignId).stream()
                .map(questionMapper::toDto)
                .toList();
    }

    @Override
    public List<ViewHistoryItemDto> history(long userId) {
        List<ViewHistoryEntity> rows =
                views.findByUserIdOrderByWatchedAtDesc(userId, PageRequest.ofSize(HISTORY_LIMIT));
        Map<Long, CampaignEntity> campaignsById = new HashMap<>();
        for (CampaignEntity c : campaigns.findAllById(rows.stream().map(ViewHistoryEntity::getCampaignId).distinct().toList())) {
            campaignsById.put(c.getId(), c);
        }
        Map<Long, String> companyNames = new HashMap<>();
        List<Long> companyIds = campaignsById.values().stream().map(CampaignEntity::getCompanyId).distinct().toList();
        for (UserEntity company : users.findAllById(companyIds)) {
            companyNames.put(company.getId(), company.getCompanyName() != null ? company.getCompanyName() : "");
        }
        return rows.stream()
                .filter(v -> campaignsById.containsKey(v.getCampaignId()))
                .map(v -> {
                    CampaignEntity c = campaignsById.get(v.getCampaignId());
                    return historyMapper.toDto(v, c, companyNames.getOrDefault(c.getCompanyId(), ""));
                })
                .toList();
    }
}
