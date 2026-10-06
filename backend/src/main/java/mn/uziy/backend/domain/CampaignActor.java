package mn.uziy.backend.domain;

/** Who is attempting a campaign status change (see {@link CampaignStatus#canTransitionTo}). */
public enum CampaignActor {
    /** The owning company (pause / resume / complete). */
    COMPANY,
    /** Super admin moderation. */
    ADMIN,
    /** The platform itself, e.g. after a successful payment. */
    SYSTEM
}
