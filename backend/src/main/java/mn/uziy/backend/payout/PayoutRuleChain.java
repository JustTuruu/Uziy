package mn.uziy.backend.payout;

import java.util.List;
import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Component;

/**
 * Pattern: Chain of Responsibility — runs every {@link PayoutRule} in order; the first
 * one that refuses the request ends the chain. New rules are new {@code @Component}s
 * (use {@code @Order} to place them).
 */
@Component
public class PayoutRuleChain {

    private final List<PayoutRule> rules;

    public PayoutRuleChain(List<PayoutRule> rules) {
        this.rules = List.copyOf(rules);
    }

    public void validate(UserEntity user, CreatePayoutReq req) {
        for (PayoutRule rule : rules) {
            rule.check(user, req);
        }
    }
}
