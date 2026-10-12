package mn.uziy.backend.viewer;

import java.util.List;
import mn.uziy.backend.common.ConflictException;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Primary;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.stereotype.Service;

/**
 * Pattern: Decorator — runs the reward transaction again when the database turns it away because it raced
 * another one. The reward runs SERIALIZABLE, so under load Postgres aborts one of two overlapping
 * transactions; that is the safety working, and the right answer is to try once more (the second look usually
 * ends in a clean "already rewarded" or "no budget left"), not to show the viewer a server error.
 *
 * <p>It wraps the transactional implementation from outside, so each attempt is its own transaction.
 */
@Service
@Primary
public class RetryingRewardService implements RewardService {

    static final int MAX_ATTEMPTS = 4;
    static final String BUSY = "Түр завгүй байна. Дахин оролдоно уу";

    private final RewardService delegate;

    public RetryingRewardService(@Qualifier("rewardServiceImpl") RewardService delegate) {
        this.delegate = delegate;
    }

    @Override
    public RewardResult submitSurvey(long userId, long campaignId, List<SubmitSurveyReq.Answer> answers) {
        for (int attempt = 1; ; attempt++) {
            try {
                return delegate.submitSurvey(userId, campaignId, answers);
            } catch (ConcurrencyFailureException e) {
                if (attempt == MAX_ATTEMPTS) {
                    throw new ConflictException(BUSY);
                }
            }
        }
    }
}
