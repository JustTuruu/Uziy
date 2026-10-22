package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class CompanyAccountMapperTest {

    private static final OffsetDateTime CREATED = OffsetDateTime.parse("2026-10-22T04:00:00Z");
    private final CompanyAccountMapper mapper = new CompanyAccountMapper();

    @Test
    void aNewAccountHasNoSurveysYet() {
        UserEntity u = new UserEntity();
        u.setId(9L);
        u.setRole(Role.COMPANY);
        u.setCompanyName("UniTel");
        u.setPhoneNumber("88001122");
        u.setCreatedAt(CREATED);

        assertThat(mapper.toDto(u)).isEqualTo(new CompanyAccountDto(9L, "UniTel", "88001122", CREATED, 0));
    }

    @Test
    void aListingRowKeepsItsCountAndNeverAMissingName() {
        assertThat(mapper.toDto(new CompanyListing(9L, null, "88001122", CREATED, 4)))
                .isEqualTo(new CompanyAccountDto(9L, "", "88001122", CREATED, 4));
    }
}
