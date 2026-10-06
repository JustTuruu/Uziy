package mn.uziy.backend.domain;

/** Payout request state: PENDING until the admin decides APPROVED or REJECTED. */
public enum PayoutStatus {
    PENDING, APPROVED, REJECTED
}
