package mn.uziy.backend.rejoin;

/**
 * What account deletion and registration need: remember a number's completed campaigns before its account is erased,
 * and hand them to the next account of the same number. Both run inside the caller's transaction.
 */
public interface CompletionCarryOver {

    /** Call while the viewer's real phone is still known, inside the deletion's transaction. */
    void rememberBeforeDeletion(long viewerId, String phone);

    /** Call for a freshly registered viewer, inside the registration's transaction. */
    void carryOverToNewAccount(long viewerId, String phone);
}
