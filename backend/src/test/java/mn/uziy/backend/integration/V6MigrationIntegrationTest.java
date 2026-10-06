package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** V6 schema: device_tokens constraints, defaults, index and cascade. Pure SQL, no Spring. */
@Testcontainers
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class V6MigrationIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_v6_test")
            .withUsername("test")
            .withPassword("test");

    private static void exec(String sql) throws SQLException {
        try (Connection c = DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
             Statement s = c.createStatement()) {
            s.execute(sql);
        }
    }

    private static int queryInt(String sql) throws SQLException {
        try (Connection c = DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
             Statement s = c.createStatement(); ResultSet rs = s.executeQuery(sql)) {
            rs.next();
            return rs.getInt(1);
        }
    }

    @BeforeAll
    void migrate() throws SQLException {
        Flyway.configure()
                .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
                .locations("classpath:db/migration").load().migrate();
        exec("""
                INSERT INTO users (id, phone_number, password_hash, role)
                VALUES (900, '90000900', 'x', 'VIEWER'), (901, '90000901', 'x', 'VIEWER')""");
    }

    @Test
    void platformIsRestrictedToAndroidAndIos() throws SQLException {
        exec("INSERT INTO device_tokens (user_id, token, platform) VALUES (900, 'p-android', 'ANDROID')");
        exec("INSERT INTO device_tokens (user_id, token, platform) VALUES (900, 'p-ios', 'IOS')");
        assertThatThrownBy(() -> exec(
                "INSERT INTO device_tokens (user_id, token, platform) VALUES (900, 'p-web', 'WEB')"))
                .isInstanceOf(SQLException.class);
    }

    @Test
    void tokenIsUniqueAcrossUsers() throws SQLException {
        exec("INSERT INTO device_tokens (user_id, token, platform) VALUES (900, 'u-1', 'ANDROID')");
        assertThatThrownBy(() -> exec(
                "INSERT INTO device_tokens (user_id, token, platform) VALUES (901, 'u-1', 'ANDROID')"))
                .isInstanceOf(SQLException.class);
    }

    @Test
    void userMustExistAndTokenAndPlatformAreRequired() {
        assertThatThrownBy(() -> exec(
                "INSERT INTO device_tokens (user_id, token, platform) VALUES (99999, 'f-1', 'IOS')"))
                .isInstanceOf(SQLException.class);
        assertThatThrownBy(() -> exec(
                "INSERT INTO device_tokens (user_id, token, platform) VALUES (900, NULL, 'IOS')"))
                .isInstanceOf(SQLException.class);
        assertThatThrownBy(() -> exec(
                "INSERT INTO device_tokens (user_id, token, platform) VALUES (900, 'f-2', NULL)"))
                .isInstanceOf(SQLException.class);
    }

    @Test
    void tokenLengthIsCappedAt512() throws SQLException {
        exec("INSERT INTO device_tokens (user_id, token, platform) VALUES (900, '" + "x".repeat(512) + "', 'IOS')");
        assertThatThrownBy(() -> exec(
                "INSERT INTO device_tokens (user_id, token, platform) VALUES (900, '" + "y".repeat(513) + "', 'IOS')"))
                .isInstanceOf(SQLException.class);
    }

    @Test
    void timestampsDefaultToNowAndUserIdIsIndexed() throws SQLException {
        exec("INSERT INTO device_tokens (user_id, token, platform) VALUES (900, 'd-1', 'ANDROID')");
        assertThat(queryInt("SELECT COUNT(*) FROM device_tokens WHERE token = 'd-1' "
                + "AND created_at IS NOT NULL AND updated_at IS NOT NULL")).isEqualTo(1);
        assertThat(queryInt("SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'device_tokens' "
                + "AND indexdef LIKE '%(user_id)%'")).isEqualTo(1);
    }

    @Test
    void deletingTheUserDeletesTheirTokens() throws SQLException {
        exec("INSERT INTO users (id, phone_number, password_hash, role) VALUES (902, '90000902', 'x', 'VIEWER')");
        exec("INSERT INTO device_tokens (user_id, token, platform) VALUES (902, 'c-1', 'ANDROID')");
        exec("DELETE FROM users WHERE id = 902");
        assertThat(queryInt("SELECT COUNT(*) FROM device_tokens WHERE token = 'c-1'")).isZero();
    }
}
