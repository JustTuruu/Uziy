package mn.uziy.backend.admin;

import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/** A company account row with how many surveys it has made, as {@link CompanyAccountRepository} reads it. */
public record CompanyListing(
        long id,
        @Nullable String companyName,
        String phoneNumber,
        OffsetDateTime createdAt,
        long campaignCount) {
}
