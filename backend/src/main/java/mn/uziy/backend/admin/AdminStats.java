package mn.uziy.backend.admin;

public record AdminStats(
        long totalUsers,
        long totalCampaigns,
        long activeCampaigns,
        /** Paid, waiting for moderation. */
        long pendingCampaigns,
        /** Created but not yet paid by the company. */
        long awaitingPaymentCampaigns,
        long pendingPayouts,
        /** Current platform commission as a fraction (0.30) — mirrors commissionPercent. */
        double commissionRate,
        /** Current platform commission, whole percent (platform_settings). */
        int commissionPercent) {
}
