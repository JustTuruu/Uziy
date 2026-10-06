package mn.uziy.backend.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class UserEntityTest {

    private static UserEntity user(Role role, String phone, LocalDate birthDate) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber(phone);
        u.setPasswordHash("x");
        u.setRole(role);
        u.setBirthDate(birthDate);
        return u;
    }

    @Test
    void ageReturnsNullWhenBirthDateIsNull() {
        UserEntity u = user(Role.COMPANY, "88112233", null);
        assertThat(u.getAge()).isNull();
    }

    @Test
    void ageComputesYearsSinceBirthDateForABirthdayAlreadyPassedThisYear() {
        LocalDate bd = LocalDate.now().minusYears(30).minusDays(30); // birthday was 30 days ago
        assertThat(user(Role.VIEWER, "1", bd).getAge()).isEqualTo(30);
    }

    @Test
    void ageSubtractsOneWhenBirthdayNotYetReachedThisYear() {
        LocalDate bd = LocalDate.now().minusYears(30).plusDays(30); // birthday hasn't arrived yet
        assertThat(user(Role.VIEWER, "1", bd).getAge()).isEqualTo(29);
    }

    @Test
    void ageIsExactlyNOnTheBirthdayItself() {
        LocalDate bd = LocalDate.now().minusYears(25);
        assertThat(user(Role.VIEWER, "1", bd).getAge()).isEqualTo(25);
    }
}
