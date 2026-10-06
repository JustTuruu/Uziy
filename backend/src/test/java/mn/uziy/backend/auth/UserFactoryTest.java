package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class UserFactoryTest {

    private final UserFactory factory = new UserFactory();

    @Test
    void buildsViewerWithProfileFields() {
        UserEntity u = factory.newViewer(new RegisterViewerReq(
                "77000001", "pw", Gender.FEMALE, LocalDate.of(2000, 5, 5), "Дархан", "1-р хороо"), "hash");
        assertThat(u.getRole()).isEqualTo(Role.VIEWER);
        assertThat(u.getPhoneNumber()).isEqualTo("77000001");
        assertThat(u.getPasswordHash()).isEqualTo("hash");
        assertThat(u.getGender()).isEqualTo(Gender.FEMALE);
        assertThat(u.getBirthDate()).isEqualTo(LocalDate.of(2000, 5, 5));
        assertThat(u.getCity()).isEqualTo("Дархан");
        assertThat(u.getDistrict()).isEqualTo("1-р хороо");
    }

    @Test
    void buildsCompanyWithName() {
        UserEntity u = factory.newCompany(new RegisterCompanyReq("88112233", "pw", "MobiCom"), "hash");
        assertThat(u.getRole()).isEqualTo(Role.COMPANY);
        assertThat(u.getCompanyName()).isEqualTo("MobiCom");
        assertThat(u.getPasswordHash()).isEqualTo("hash");
        assertThat(u.getGender()).isNull();
    }
}
