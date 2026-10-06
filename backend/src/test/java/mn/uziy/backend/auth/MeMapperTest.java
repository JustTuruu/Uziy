package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class MeMapperTest {

    @Test
    void mapsAllFields() {
        UserEntity u = new UserEntity();
        u.setId(7L);
        u.setPhoneNumber("99112233");
        u.setPasswordHash("x");
        u.setRole(Role.VIEWER);
        u.setGender(Gender.MALE);
        u.setBirthDate(LocalDate.now().minusYears(30).minusDays(1));
        u.setCity("Улаанбаатар");
        u.setBalance(1200.0);

        Me me = new MeMapper().toMe(u);

        assertThat(me.id()).isEqualTo(7L);
        assertThat(me.phoneNumber()).isEqualTo("99112233");
        assertThat(me.role()).isEqualTo(Role.VIEWER);
        assertThat(me.gender()).isEqualTo(Gender.MALE);
        assertThat(me.age()).isEqualTo(30);
        assertThat(me.city()).isEqualTo("Улаанбаатар");
        assertThat(me.balance()).isEqualTo(1200.0);
        assertThat(me.isVerified()).isFalse();
        assertThat(me.companyName()).isNull();
    }
}
