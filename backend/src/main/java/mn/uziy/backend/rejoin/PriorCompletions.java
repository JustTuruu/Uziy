package mn.uziy.backend.rejoin;

import java.util.Set;

/**
 * What the feed and the reward need: the campaigns a viewer counts as having completed under an earlier, deleted
 * account of the same number (in addition to their own view history).
 */
public interface PriorCompletions {

    Set<Long> inheritedCampaignIds(long viewerId);

    boolean isInherited(long viewerId, long campaignId);
}
