package mn.uziy.backend.domain;

/**
 * Pattern: State — single source of truth for the campaign lifecycle.
 *
 * <p>Lifecycle (V5): created → AWAITING_PAYMENT → (company pays) → PENDING
 * (= paid, awaiting admin moderation) → ACTIVE | REJECTED. Afterwards the
 * company may toggle ACTIVE ⇄ PAUSED and end with COMPLETED.
 *
 * <p>Legal transitions per actor:
 * <ul>
 *   <li>SYSTEM: AWAITING_PAYMENT → PENDING</li>
 *   <li>ADMIN: PENDING → ACTIVE | REJECTED</li>
 *   <li>COMPANY: ACTIVE → PAUSED | COMPLETED; PAUSED → ACTIVE | COMPLETED</li>
 * </ul>
 * COMPLETED and REJECTED are terminal.
 */
public enum CampaignStatus {
    AWAITING_PAYMENT, PENDING, ACTIVE, PAUSED, COMPLETED, REJECTED;

    /** True if {@code actor} may move a campaign from this status to {@code next}. */
    public boolean canTransitionTo(CampaignStatus next, CampaignActor actor) {
        if (next == null || actor == null) {
            return false;
        }
        switch (actor) {
            case SYSTEM:
                return this == AWAITING_PAYMENT && next == PENDING;
            case ADMIN:
                return this == PENDING && (next == ACTIVE || next == REJECTED);
            case COMPANY:
                return (this == ACTIVE && (next == PAUSED || next == COMPLETED))
                        || (this == PAUSED && (next == ACTIVE || next == COMPLETED));
            default:
                return false;
        }
    }
}
