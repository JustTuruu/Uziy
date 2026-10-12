package mn.uziy.backend.domain;

/** Completed views of one campaign and what they paid out; row type of {@code ViewHistoryRepository.statsByCompany}. */
public record CampaignViewStats(long campaignId, long views, double rewardsPaid) {
}
