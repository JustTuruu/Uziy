package mn.uziy.backend.payout;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.PayoutStatus;
import org.springframework.stereotype.Component;

/** Pattern: Factory/Registry — picks the {@link PayoutDecisionStrategy} for a decision. */
@Component
public class PayoutDecisionStrategies {

    private final Map<PayoutStatus, PayoutDecisionStrategy> byDecision = new EnumMap<>(PayoutStatus.class);

    public PayoutDecisionStrategies(List<PayoutDecisionStrategy> strategies) {
        for (PayoutDecisionStrategy s : strategies) {
            byDecision.put(s.decision(), s);
        }
    }

    /** @throws BadRequestException when no strategy exists (PENDING is not a decision) */
    public PayoutDecisionStrategy forDecision(PayoutStatus decision) {
        PayoutDecisionStrategy strategy = byDecision.get(decision);
        if (strategy == null) {
            throw new BadRequestException("Cannot set PENDING");
        }
        return strategy;
    }
}
