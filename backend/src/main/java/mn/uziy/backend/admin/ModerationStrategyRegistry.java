package mn.uziy.backend.admin;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import mn.uziy.backend.domain.CampaignStatus;
import org.springframework.stereotype.Component;

/** Pattern: Factory/Registry — picks the {@link ModerationStrategy} for a requested decision. */
@Component
public class ModerationStrategyRegistry {

    private final Map<CampaignStatus, ModerationStrategy> byTarget = new EnumMap<>(CampaignStatus.class);

    public ModerationStrategyRegistry(List<ModerationStrategy> strategies) {
        for (ModerationStrategy s : strategies) {
            byTarget.put(s.target(), s);
        }
    }

    public Optional<ModerationStrategy> find(CampaignStatus decision) {
        return Optional.ofNullable(byTarget.get(decision));
    }
}
