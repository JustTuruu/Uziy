package mn.uziy.backend.domain;

/**
 * Lifecycle (V5): created → AWAITING_PAYMENT → (company pays) → PENDING
 * (= paid, awaiting admin moderation) → ACTIVE | REJECTED. Afterwards the
 * company may toggle ACTIVE ⇄ PAUSED and end with COMPLETED.
 */
public enum CampaignStatus {
    AWAITING_PAYMENT, PENDING, ACTIVE, PAUSED, COMPLETED, REJECTED
}
