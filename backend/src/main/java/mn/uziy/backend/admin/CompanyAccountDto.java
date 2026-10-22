package mn.uziy.backend.admin;

import java.time.OffsetDateTime;

/** One company account as the admin's "Компаниуд" page lists it. */
public record CompanyAccountDto(
        long id,
        String companyName,
        String phoneNumber,
        OffsetDateTime createdAt,
        long campaignCount) {
}
