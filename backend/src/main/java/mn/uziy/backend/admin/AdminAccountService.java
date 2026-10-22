package mn.uziy.backend.admin;

import java.util.List;

/** An admin opens other admins' accounts (there is no self sign-up for admins) and lists them. */
public interface AdminAccountService {

    /**
     * Opens an admin account with a temporary password the creating admin hands over.
     *
     * @throws mn.uziy.backend.common.ConflictException when the phone already has an account (of any role)
     */
    AdminAccountDto create(CreateAdminReq req, long adminId);

    /** Every admin account, newest first; the read is written to the data access log. */
    List<AdminAccountDto> list(long adminId);
}
