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
                "77000001", "pw", "Бат", "Болд", Gender.FEMALE, LocalDate.of(2000, 5, 5), "Дархан", "1-р хороо", java.util.UUID.randomUUID()), "hash");
        assertThat(u.getRole()).isEqualTo(Role.VIEWER);
        assertThat(u.getPhoneNumber()).isEqualTo("77000001");
        assertThat(u.getPasswordHash()).isEqualTo("hash");
        assertThat(u.getGender()).isEqualTo(Gender.FEMALE);
        assertThat(u.getBirthDate()).isEqualTo(LocalDate.of(2000, 5, 5));
        assertThat(u.getCity()).isEqualTo("Дархан");
        assertThat(u.getDistrict()).isEqualTo("1-р хороо");
        assertThat(u.getLastName()).isEqualTo("Бат");
        assertThat(u.getFirstName()).isEqualTo("Болд");
    }

    @Test
    void storesTheNamesWithoutSurroundingSpaces() {
        UserEntity u = factory.newViewer(new RegisterViewerReq("77000001", "password1", "  Оюун-Эрдэнэ ",
                " Төрболд  ", Gender.MALE, LocalDate.of(2000, 5, 5), "Дархан", java.util.UUID.randomUUID()), "hash");
        assertThat(u.getLastName()).isEqualTo("Оюун-Эрдэнэ");
        assertThat(u.getFirstName()).isEqualTo("Төрболд");
    }

    @Test
    void buildsCompanyWithName() {
        UserEntity u = factory.newCompany("88112233", "  MobiCom ", "hash");
        assertThat(u.getRole()).isEqualTo(Role.COMPANY);
        assertThat(u.getCompanyName()).isEqualTo("MobiCom");
        assertThat(u.getPasswordHash()).isEqualTo("hash");
        assertThat(u.getPhoneNumber()).isEqualTo("88112233");
        assertThat(u.getGender()).isNull();
    }

    @Test
    void anAdminHasOnlyAPhoneAndAPassword() {
        UserEntity u = factory.newAdmin("88112233", "hash");
        assertThat(u.getRole()).isEqualTo(Role.ADMIN);
        assertThat(u.getPhoneNumber()).isEqualTo("88112233");
        assertThat(u.getPasswordHash()).isEqualTo("hash");
        assertThat(u.getCompanyName()).isNull();
        assertThat(u.getGender()).isNull();
    }
}
