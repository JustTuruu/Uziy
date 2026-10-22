package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class AdminAccountMapperTest {

    @Test
    void keepsOnlyIdPhoneAndCreationTime() {
        OffsetDateTime created = OffsetDateTime.parse("2026-10-22T04:00:00Z");
        UserEntity u = new UserEntity();
        u.setId(9L);
        u.setRole(Role.ADMIN);
        u.setPhoneNumber("88001122");
        u.setPasswordHash("bcrypt");
        u.setCreatedAt(created);

        assertThat(new AdminAccountMapper().toDto(u)).isEqualTo(new AdminAccountDto(9L, "88001122", created));
    }
}
