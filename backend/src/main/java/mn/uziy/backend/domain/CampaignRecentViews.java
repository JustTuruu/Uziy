package mn.uziy.backend.domain;

/** Completed views of one campaign inside a recent window; row type of {@code ViewHistoryRepository.recentByCompany}. */
public record CampaignRecentViews(long campaignId, long views) {
}
