package mn.uziy.backend.tools;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Verifies the bootstrap CLI helpers against a real Postgres:
 * - {@code bcrypt()} returns a hash that Spring's PasswordEncoder can verify
 *   (proves the seed-hash workflow round-trips)
 * - {@code makeAdmin()} upserts an ADMIN row and re-running is idempotent
 */
@SpringBootTest
@Testcontainers
class BootstrapTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    UserRepository users;

    @Autowired
    PasswordEncoder encoder;

    private long admin(String phone, String password) {
        return Bootstrap.makeAdmin(phone, password,
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
    }

    @Test
    void bcryptOutputVerifiesAgainstSpringsPasswordEncoder() {
        String hash = Bootstrap.bcrypt("hunter2");
        assertThat(encoder.matches("hunter2", hash))
                .as("hash produced by bcrypt() must round-trip through PasswordEncoder")
                .isTrue();
    }

    @Test
    void bcryptRejectsEmptyPassword() {
        assertThatThrownBy(() -> Bootstrap.bcrypt("")).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void makeAdminInsertsANewAdminWithTheCorrectRoleAndVerifiedFlag() {
        long id = admin("77555001", "hunter2");
        UserEntity u = users.findById(id).orElseThrow();
        assertThat(u.getRole()).isEqualTo(Role.ADMIN);
        assertThat(u.isVerified()).isTrue();
        assertThat(encoder.matches("hunter2", u.getPasswordHash())).isTrue();
    }

    @Test
    void makeAdminRerunOnSamePhoneUpdatesRoleAndPassword() {
        long id1 = admin("77555002", "first-password");
        long id2 = admin("77555002", "second-password");

        assertThat(id2).as("same phone should upsert to the same row").isEqualTo(id1);

        UserEntity u = users.findById(id1).orElseThrow();
        assertThat(u.getRole()).isEqualTo(Role.ADMIN);
        assertThat(encoder.matches("second-password", u.getPasswordHash()))
                .as("password should be updated on re-run").isTrue();
        assertThat(encoder.matches("first-password", u.getPasswordHash()))
                .as("old password should no longer verify").isFalse();
    }

    @Test
    void makeAdminRejectsMalformedPhone() {
        assertThatThrownBy(() -> admin("bad-phone", "hunter2")).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void makeAdminRejectsShortPassword() {
        assertThatThrownBy(() -> admin("77555003", "short")).isInstanceOf(IllegalArgumentException.class);
    }
}
