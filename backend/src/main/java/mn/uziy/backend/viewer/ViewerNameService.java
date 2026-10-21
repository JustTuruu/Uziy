package mn.uziy.backend.viewer;

import mn.uziy.backend.auth.Me;

/**
 * Use case: a viewer whose account predates the name fields gives their овог + нэр, once. The name takes part in
 * the payout check (the bank account must be in the viewer's own name), so it is never edited here afterwards.
 */
public interface ViewerNameService {

    /** Sets the name and returns the updated profile; 409 when the account already has one. */
    Me setNameOnce(long viewerId, String lastName, String firstName);
}
