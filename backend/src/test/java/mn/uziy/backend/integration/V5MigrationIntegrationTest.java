package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Upgrade path for V5 on a database that already has data: migrate to V4
 * (dev seed included), add legacy rows the way the old app would have, then
 * apply V5 and check the backfill + the new constraints. No Spring context —
 * this is purely about the SQL.
 */
@Testcontainers
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class V5MigrationIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_v5_test")
            .withUsername("test")
            .withPassword("test");

    @FunctionalInterface
    private interface SqlFunction<T> {
        T apply(Connection c) throws SQLException;
    }

    private static Flyway flyway(@Nullable String target) {
        var config = Flyway.configure()
                .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
                .locations("classpath:db/migration");
        if (target != null) {
            config.target(target);
        }
        return config.load();
    }

    private static <T> T db(SqlFunction<T> block) throws SQLException {
        try (Connection c = DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {
            return block.apply(c);
        }
    }

    private static void exec(String sql) throws SQLException {
        db(c -> {
            try (Statement s = c.createStatement()) {
                return s.execute(sql);
            }
        });
    }

    private static @Nullable Integer queryInt(String sql) throws SQLException {
        return db(c -> {
            try (Statement s = c.createStatement(); ResultSet rs = s.executeQuery(sql)) {
                rs.next();
                Object v = rs.getObject(1);
                return v == null ? null : ((Number) v).intValue();
            }
        });
    }

    private static @Nullable String queryString(String sql) throws SQLException {
        return db(c -> {
            try (Statement s = c.createStatement(); ResultSet rs = s.executeQuery(sql)) {
                rs.next();
                return rs.getString(1);
            }
        });
    }

    @BeforeAll
    void migrate() throws SQLException {
        flyway("4").migrate();
        assertThat(queryInt("SELECT COUNT(*) FROM campaigns")).as("V2 seed present before V5").isEqualTo(3);

        // Legacy rows created by the pre-V5 app: a survey-only one, one whose
        // budget is below a single view, and a paused one.
        exec("""
                INSERT INTO campaigns (id, company_id, title, duration_seconds, has_video,
                                       total_budget, remaining_budget, cost_per_view, reward_per_user, status)
                VALUES (50, 2, 'legacy survey', 0, FALSE, 200000, 200000, 400, 250, 'PENDING'),
                       (51, 2, 'tiny',          30, TRUE,  500,    500,    1000, 700, 'ACTIVE'),
                       (52, 3, 'paused',        30, TRUE,  999999, 10000,  1000, 700, 'PAUSED');
                """);
        exec("UPDATE platform_settings SET survey_only_cost_per_response = 600, survey_only_reward_per_user = 350");

        MigrateResult result = flyway("5").migrate();
        assertThat(result.targetSchemaVersion).isEqualTo("5");
    }

    private static @Nullable Integer viewers(int id) throws SQLException {
        return queryInt("SELECT target_viewers FROM campaigns WHERE id = " + id);
    }

    @Test
    void target_viewers_is_backfilled_as_floor_total_budget_div_cost_per_view_at_least_1() throws SQLException {
        assertThat(viewers(1)).isEqualTo(5000);
        assertThat(viewers(2)).isEqualTo(3750);
        assertThat(viewers(3)).isEqualTo(3333);
        assertThat(viewers(50)).isEqualTo(500);
        assertThat(viewers(51)).isEqualTo(1);
        assertThat(viewers(52)).isEqualTo(999);
        // Only rows that existed when V5 ran (ids < 60): later tests insert fresh rows
        // that legitimately have no target_viewers, whatever order JUnit runs them in.
        assertThat(queryInt(
                "SELECT COUNT(*) FROM campaigns WHERE id < 60 AND target_viewers IS NULL")).isEqualTo(0);
    }

    @Test
    void legacy_rows_keep_their_status_and_have_no_commission_snapshot_or_paid_at() throws SQLException {
        assertThat(queryString("SELECT status FROM campaigns WHERE id = 50")).isEqualTo("PENDING");
        assertThat(queryString("SELECT status FROM campaigns WHERE id = 52")).isEqualTo("PAUSED");
        assertThat(queryInt(
                "SELECT COUNT(*) FROM campaigns WHERE id < 60 AND (commission_percent IS NOT NULL OR paid_at IS NOT NULL)"))
                .isEqualTo(0);
    }

    @Test
    void platform_settings_get_the_commission_model_and_lose_the_survey_pricing() throws SQLException {
        assertThat(queryInt("SELECT commission_percent FROM platform_settings WHERE id = 1")).isEqualTo(30);
        assertThat(queryInt("SELECT min_reward_per_viewer FROM platform_settings WHERE id = 1")).isEqualTo(100);
        assertThat(queryInt("""
                SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_name = 'platform_settings' AND column_name LIKE 'survey_only%'
                """)).isEqualTo(0);
        assertThatThrownBy(() -> exec("UPDATE platform_settings SET commission_percent = 0"))
                .isInstanceOf(SQLException.class);
        assertThatThrownBy(() -> exec("UPDATE platform_settings SET commission_percent = 91"))
                .isInstanceOf(SQLException.class);
        assertThatThrownBy(() -> exec("UPDATE platform_settings SET min_reward_per_viewer = 0"))
                .isInstanceOf(SQLException.class);
    }

    @Test
    void status_CHECK_accepts_AWAITING_PAYMENT_rejects_garbage_and_it_is_the_default() throws SQLException {
        exec("""
                INSERT INTO campaigns (id, company_id, title, duration_seconds, total_budget,
                                       remaining_budget, cost_per_view, reward_per_user)
                VALUES (60, 2, 'defaulted', 30, 1000, 1000, 1000, 700)
                """);
        assertThat(queryString("SELECT status FROM campaigns WHERE id = 60")).isEqualTo("AWAITING_PAYMENT");
        exec("UPDATE campaigns SET status = 'PENDING' WHERE id = 60");
        exec("UPDATE campaigns SET status = 'AWAITING_PAYMENT' WHERE id = 60");
        assertThatThrownBy(() -> exec("UPDATE campaigns SET status = 'BOGUS' WHERE id = 60"))
                .isInstanceOf(SQLException.class);
        // The new columns carry their CHECKs too.
        assertThatThrownBy(() -> exec("UPDATE campaigns SET target_viewers = 0 WHERE id = 60"))
                .isInstanceOf(SQLException.class);
        assertThatThrownBy(() -> exec("UPDATE campaigns SET commission_percent = 91 WHERE id = 60"))
                .isInstanceOf(SQLException.class);
        // reward_lt_cost from V1 still holds.
        assertThatThrownBy(() -> exec("UPDATE campaigns SET reward_per_user = 1000 WHERE id = 60"))
                .isInstanceOf(SQLException.class);
    }

    @Test
    void campaign_payments_allows_at_most_one_PAID_row_per_campaign() throws SQLException {
        exec("""
                INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                VALUES (1, 2, 1000, 'QPAY', 'FAILED', 'UZ-T-1-a'),
                       (1, 2, 1000, 'SIMULATED', 'PAID', 'UZ-T-1-b')
                """);
        // Second PAID row for the same campaign -> unique partial index.
        assertThatThrownBy(() -> exec("""
                INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                VALUES (1, 2, 1000, 'SIMULATED', 'PAID', 'UZ-T-1-c')"""))
                .isInstanceOf(SQLException.class);
        // Duplicate reference.
        assertThatThrownBy(() -> exec("""
                INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                VALUES (2, 3, 1000, 'SIMULATED', 'FAILED', 'UZ-T-1-a')"""))
                .isInstanceOf(SQLException.class);
        // Enum-ish CHECKs and positive amount.
        assertThatThrownBy(() -> exec("""
                INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                VALUES (2, 3, 1000, 'PAYPAL', 'PAID', 'UZ-T-2-a')"""))
                .isInstanceOf(SQLException.class);
        assertThatThrownBy(() -> exec("""
                INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                VALUES (2, 3, 0, 'SIMULATED', 'PAID', 'UZ-T-2-b')"""))
                .isInstanceOf(SQLException.class);
        assertThat(queryInt(
                "SELECT COUNT(*) FROM campaign_payments WHERE campaign_id = 1 AND status = 'PAID'")).isEqualTo(1);
        assertThat(queryString("SELECT paid_at FROM campaign_payments WHERE reference = 'UZ-T-1-a'")).isNull();
    }
}
