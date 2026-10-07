package mn.uziy.backend.guest;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.viewer.FeedItemDto;
import mn.uziy.backend.viewer.FeedItemMapper;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

@Service
public class GuestFeedServiceImpl implements GuestFeedService {

    private final CampaignRepository campaigns;
    private final UserRepository users;
    private final FeedItemMapper mapper;

    public GuestFeedServiceImpl(CampaignRepository campaigns, UserRepository users, FeedItemMapper mapper) {
        this.campaigns = campaigns;
        this.users = users;
        this.mapper = mapper;
    }

    @Override
    public List<FeedItemDto> sampleFeed() {
        List<CampaignEntity> sample = campaigns.findPayableNewestFirst(PageRequest.ofSize(SAMPLE_SIZE));
        List<Long> companyIds = sample.stream().map(CampaignEntity::getCompanyId).distinct().toList();
        Map<Long, String> companyNames = new HashMap<>();
        for (UserEntity company : users.findAllById(companyIds)) {
            companyNames.put(company.getId(), company.getCompanyName() != null ? company.getCompanyName() : "");
        }
        return sample.stream()
                .map(c -> mapper.toGuestDto(c, companyNames.getOrDefault(c.getCompanyId(), "")))
                .toList();
    }
}
