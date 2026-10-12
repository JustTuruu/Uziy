package mn.uziy.backend.security;

import java.util.concurrent.atomic.AtomicInteger;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;

/**
 * Real HTTP stack (security filter chain, validation, exception handling) over a real Postgres that
 * ran every Flyway migration. One container serves every subclass so Spring reuses a single context.
 * Each helper creates its own rows with a fresh phone number, so tests never depend on each other
 * or on the dev seed.
 */
@SpringBootTest
@AutoConfigureMockMvc
public abstract class AbstractApiIntegrationTest {

    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_audit")
            .withUsername("test")
            .withPassword("test");

    static {
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("uziy.payments.simulated", () -> "true");
    }

    protected static final String PASSWORD = "Correct-Horse-1";
    private static final AtomicInteger PHONES = new AtomicInteger(10_000);

    @Autowired protected MockMvc mvc;
    @Autowired protected JdbcTemplate jdbc;
    @Autowired protected JwtService jwt;
    @Autowired protected UserRepository users;
    @Autowired protected PasswordEncoder encoder;

    /** A phone number nobody else in this JVM has used (and not one of the dev seed's). */
    protected static String freshPhone() {
        return "6" + String.format("%07d", PHONES.incrementAndGet());
    }

    protected long insertUser(String role, String gender, String birthDate, String city, String companyName,
                              double balance) {
        return jdbc.queryForObject("""
                INSERT INTO users (phone_number, password_hash, role, gender, birth_date, city, company_name, balance)
                VALUES (?, ?, ?, ?, CAST(? AS date), ?, ?, ?) RETURNING id""",
                Long.class, freshPhone(), encoder.encode(PASSWORD), role, gender, birthDate, city, companyName,
                balance);
    }

    protected long viewer(double balance) {
        return insertUser("VIEWER", "MALE", "2000-01-01", "Улаанбаатар", null, balance);
    }

    protected long company() {
        return insertUser("COMPANY", null, null, null, "AuditCo", 0);
    }

    protected long admin() {
        return insertUser("ADMIN", null, null, null, null, 0);
    }

    protected String phoneOf(long userId) {
        return jdbc.queryForObject("SELECT phone_number FROM users WHERE id = ?", String.class, userId);
    }

    protected String tokenOf(long userId) {
        return jwt.issue(users.findById(userId).orElseThrow());
    }

    protected String bearer(long userId) {
        return "Bearer " + tokenOf(userId);
    }

    /** An ACTIVE campaign with 100 ₮ cost per view, 70 reward and plenty of budget, open to everyone. */
    protected long activeCampaign(long companyId) {
        return campaign(companyId, "ACTIVE", "ALL", 0, 100, "ALL");
    }

    protected long campaign(long companyId, String status, String gender, int minAge, int maxAge, String city) {
        return jdbc.queryForObject("""
                INSERT INTO campaigns (company_id, title, duration_seconds, target_gender, min_age, max_age,
                    target_city, total_budget, remaining_budget, cost_per_view, reward_per_user, status,
                    target_viewers, paid_at)
                VALUES (?, 'Audit', 30, ?, ?, ?, ?, 100000, 100000, 100, 70, ?, 1000, NOW()) RETURNING id""",
                Long.class, companyId, gender, minAge, maxAge, city, status);
    }

    protected long question(long campaignId, int position, String type, String optionsJson, boolean required) {
        return jdbc.queryForObject("""
                INSERT INTO survey_questions (campaign_id, position, prompt, q_type, options_json, required)
                VALUES (?, ?, 'Q', ?, CAST(? AS jsonb), ?) RETURNING id""",
                Long.class, campaignId, position, type, optionsJson, required);
    }

    protected double balanceOf(long userId) {
        return jdbc.queryForObject("SELECT balance FROM users WHERE id = ?", Double.class, userId);
    }
}
