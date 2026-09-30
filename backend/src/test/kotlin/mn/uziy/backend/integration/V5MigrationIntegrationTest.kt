package mn.uziy.backend.integration

import org.flywaydb.core.Flyway
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestInstance
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import java.sql.Connection
import java.sql.DriverManager
import java.sql.SQLException
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

/**
 * Upgrade path for V5 on a database that already has data: migrate to V4
 * (dev seed included), add legacy rows the way the old app would have, then
 * apply V5 and check the backfill + the new constraints. No Spring context —
 * this is purely about the SQL.
 */
@Testcontainers
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class V5MigrationIntegrationTest {

    companion object {
        @Container
        @JvmStatic
        val postgres: PostgreSQLContainer<*> = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("uziy_v5_test")
            .withUsername("test")
            .withPassword("test")
    }

    private fun flyway(target: String? = null) = Flyway.configure()
        .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
        .locations("classpath:db/migration")
        .apply { if (target != null) target(target) }
        .load()

    private fun <T> db(block: (Connection) -> T): T =
        DriverManager.getConnection(postgres.jdbcUrl, postgres.username, postgres.password).use(block)

    private fun exec(sql: String) = db { it.createStatement().use { s -> s.execute(sql) } }

    private fun queryInt(sql: String): Int? = db { c ->
        c.createStatement().use { s ->
            s.executeQuery(sql).use { rs -> rs.next(); rs.getObject(1)?.let { (it as Number).toInt() } }
        }
    }

    private fun queryString(sql: String): String? = db { c ->
        c.createStatement().use { s -> s.executeQuery(sql).use { rs -> rs.next(); rs.getString(1) } }
    }

    @BeforeAll
    fun migrate() {
        flyway(target = "4").migrate()
        assertEquals(3, queryInt("SELECT COUNT(*) FROM campaigns"), "V2 seed present before V5")

        // Legacy rows created by the pre-V5 app: a survey-only one, one whose
        // budget is below a single view, and a paused one.
        exec("""
            INSERT INTO campaigns (id, company_id, title, duration_seconds, has_video,
                                   total_budget, remaining_budget, cost_per_view, reward_per_user, status)
            VALUES (50, 2, 'legacy survey', 0, FALSE, 200000, 200000, 400, 250, 'PENDING'),
                   (51, 2, 'tiny',          30, TRUE,  500,    500,    1000, 700, 'ACTIVE'),
                   (52, 3, 'paused',        30, TRUE,  999999, 10000,  1000, 700, 'PAUSED');
        """.trimIndent())
        exec("UPDATE platform_settings SET survey_only_cost_per_response = 600, survey_only_reward_per_user = 350")

        val result = flyway().migrate()
        assertEquals("5", result.targetSchemaVersion)
    }

    @Test
    fun `target_viewers is backfilled as floor(total_budget div cost_per_view), at least 1`() {
        fun viewers(id: Int) = queryInt("SELECT target_viewers FROM campaigns WHERE id = $id")
        assertEquals(5000, viewers(1))
        assertEquals(3750, viewers(2))
        assertEquals(3333, viewers(3))
        assertEquals(500, viewers(50))
        assertEquals(1, viewers(51))
        assertEquals(999, viewers(52))
        assertEquals(0, queryInt("SELECT COUNT(*) FROM campaigns WHERE target_viewers IS NULL"))
    }

    @Test
    fun `legacy rows keep their status and have no commission snapshot or paid_at`() {
        assertEquals("PENDING", queryString("SELECT status FROM campaigns WHERE id = 50"))
        assertEquals("PAUSED", queryString("SELECT status FROM campaigns WHERE id = 52"))
        assertEquals(0, queryInt(
            "SELECT COUNT(*) FROM campaigns WHERE commission_percent IS NOT NULL OR paid_at IS NOT NULL"))
    }

    @Test
    fun `platform settings get the commission model and lose the survey pricing`() {
        assertEquals(30, queryInt("SELECT commission_percent FROM platform_settings WHERE id = 1"))
        assertEquals(100, queryInt("SELECT min_reward_per_viewer FROM platform_settings WHERE id = 1"))
        assertEquals(0, queryInt("""
            SELECT COUNT(*) FROM information_schema.columns
             WHERE table_name = 'platform_settings' AND column_name LIKE 'survey_only%'
        """))
        assertFailsWith<SQLException> { exec("UPDATE platform_settings SET commission_percent = 0") }
        assertFailsWith<SQLException> { exec("UPDATE platform_settings SET commission_percent = 91") }
        assertFailsWith<SQLException> { exec("UPDATE platform_settings SET min_reward_per_viewer = 0") }
    }

    @Test
    fun `status CHECK accepts AWAITING_PAYMENT, rejects garbage, and it is the default`() {
        exec("""
            INSERT INTO campaigns (id, company_id, title, duration_seconds, total_budget,
                                   remaining_budget, cost_per_view, reward_per_user)
            VALUES (60, 2, 'defaulted', 30, 1000, 1000, 1000, 700)
        """.trimIndent())
        assertEquals("AWAITING_PAYMENT", queryString("SELECT status FROM campaigns WHERE id = 60"))
        exec("UPDATE campaigns SET status = 'PENDING' WHERE id = 60")
        exec("UPDATE campaigns SET status = 'AWAITING_PAYMENT' WHERE id = 60")
        assertFailsWith<SQLException> { exec("UPDATE campaigns SET status = 'BOGUS' WHERE id = 60") }
        // The new columns carry their CHECKs too.
        assertFailsWith<SQLException> { exec("UPDATE campaigns SET target_viewers = 0 WHERE id = 60") }
        assertFailsWith<SQLException> { exec("UPDATE campaigns SET commission_percent = 91 WHERE id = 60") }
        // reward_lt_cost from V1 still holds.
        assertFailsWith<SQLException> { exec("UPDATE campaigns SET reward_per_user = 1000 WHERE id = 60") }
    }

    @Test
    fun `campaign_payments allows at most one PAID row per campaign`() {
        exec("""
            INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
            VALUES (1, 2, 1000, 'QPAY', 'FAILED', 'UZ-T-1-a'),
                   (1, 2, 1000, 'SIMULATED', 'PAID', 'UZ-T-1-b')
        """.trimIndent())
        // Second PAID row for the same campaign → unique partial index.
        assertFailsWith<SQLException> {
            exec("""INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                    VALUES (1, 2, 1000, 'SIMULATED', 'PAID', 'UZ-T-1-c')""")
        }
        // Duplicate reference.
        assertFailsWith<SQLException> {
            exec("""INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                    VALUES (2, 3, 1000, 'SIMULATED', 'FAILED', 'UZ-T-1-a')""")
        }
        // Enum-ish CHECKs and positive amount.
        assertFailsWith<SQLException> {
            exec("""INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                    VALUES (2, 3, 1000, 'PAYPAL', 'PAID', 'UZ-T-2-a')""")
        }
        assertFailsWith<SQLException> {
            exec("""INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                    VALUES (2, 3, 0, 'SIMULATED', 'PAID', 'UZ-T-2-b')""")
        }
        assertEquals(1, queryInt("SELECT COUNT(*) FROM campaign_payments WHERE campaign_id = 1 AND status = 'PAID'"))
        assertNull(queryString("SELECT paid_at FROM campaign_payments WHERE reference = 'UZ-T-1-a'"))
    }
}
