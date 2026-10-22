package mn.uziy.backend.admin;

import java.util.List;

/** The admin opens company accounts (companies cannot register themselves) and lists them. */
public interface CompanyAccountService {

    /**
     * Opens a company account with a temporary password the admin hands over.
     *
     * @throws mn.uziy.backend.common.ConflictException when the phone already has an account (of any role)
     */
    CompanyAccountDto create(CreateCompanyReq req, long adminId);

    /** Every company account, newest first; the read is written to the data access log. */
    List<CompanyAccountDto> list(long adminId);
}
