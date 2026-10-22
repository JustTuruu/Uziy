package mn.uziy.backend.admin;

import mn.uziy.backend.domain.UserEntity;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — company accounts (a fresh entity or a listing row) to {@link CompanyAccountDto}. */
@Component
public class CompanyAccountMapper {

    /** A just-created account has made no surveys yet. */
    public CompanyAccountDto toDto(UserEntity company) {
        return new CompanyAccountDto(company.getId(), nameOf(company.getCompanyName()), company.getPhoneNumber(),
                company.getCreatedAt(), 0);
    }

    public CompanyAccountDto toDto(CompanyListing row) {
        return new CompanyAccountDto(row.id(), nameOf(row.companyName()), row.phoneNumber(), row.createdAt(),
                row.campaignCount());
    }

    /** Company rows always carry a name; an old row without one must not break the list. */
    private static String nameOf(@Nullable String name) {
        return name == null ? "" : name;
    }
}
