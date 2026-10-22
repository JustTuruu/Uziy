package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;

import mn.uziy.backend.consolelogin.ConsoleLoginChallenge;
import mn.uziy.backend.auth.AuthController;
import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.auth.LoginReq;
import mn.uziy.backend.domain.Role;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Regression test — proves the V3 seed-password fix actually made the
 * dev-seed users loginable. If someone breaks V3 or the seed passwords
 * drift, this test screams before the frontend team hits it.
 */
@SpringBootTest
@Testcontainers
class SeedLoginIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_seed_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    AuthController auth;

    private AuthResponse signedIn(String phone) {
        ResponseEntity<Object> res = auth.login(new LoginReq(phone, "password"));
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.OK);
        return (AuthResponse) res.getBody();
    }

    /** The password is right, but an admin still has to prove the phone: no token at this step. */
    @Test
    void seeded_admin_id_1_passes_the_password_step_with_password_password() {
        ResponseEntity<Object> res = auth.login(new LoginReq("99990000", "password"));
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        assertThat(res.getBody()).isInstanceOf(ConsoleLoginChallenge.class);
        assertThat(((ConsoleLoginChallenge) res.getBody()).twoStep().role()).isEqualTo(Role.ADMIN);
    }

    /** A company proves its phone too on a browser it has not used before (owner, 2026-10-22). */
    @Test
    void seeded_company_MobiCom_passes_the_password_step_with_password_password() {
        ResponseEntity<Object> res = auth.login(new LoginReq("88112233", "password"));
        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        assertThat(((ConsoleLoginChallenge) res.getBody()).twoStep().role()).isEqualTo(Role.COMPANY);
    }

    @Test
    void seeded_viewer_id_100_can_log_in_with_password_password() {
        AuthResponse res = signedIn("88778899");
        assertThat(res.user().role()).isEqualTo(Role.VIEWER);
        assertThat(res.user().city()).isEqualTo("Улаанбаатар");
    }
}
