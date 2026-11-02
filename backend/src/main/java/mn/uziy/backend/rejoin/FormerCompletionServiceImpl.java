package mn.uziy.backend.rejoin;

import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Stops "delete the account, register the number again, earn the same campaigns again" (owner, 2026-11-02). Only the
 * keyed phone hash ({@link PhoneFingerprint}) and campaign ids are kept — nothing that names the person. The writes
 * require the caller's transaction: if the deletion or the registration rolls back, so does this.
 */
@Service
public class FormerCompletionServiceImpl implements CompletionCarryOver, PriorCompletions {

    private final FormerCompletionRepository completions;
    private final PhoneFingerprint fingerprint;

    public FormerCompletionServiceImpl(FormerCompletionRepository completions, PhoneFingerprint fingerprint) {
        this.completions = completions;
        this.fingerprint = fingerprint;
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void rememberBeforeDeletion(long viewerId, String phone) {
        completions.rememberCompletionsOf(viewerId, fingerprint.of(phone));
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void carryOverToNewAccount(long viewerId, String phone) {
        completions.inheritInto(viewerId, fingerprint.of(phone));
    }

    @Override
    public Set<Long> inheritedCampaignIds(long viewerId) {
        return completions.inheritedCampaignIds(viewerId);
    }

    @Override
    public boolean isInherited(long viewerId, long campaignId) {
        return completions.isInherited(viewerId, campaignId);
    }
}
