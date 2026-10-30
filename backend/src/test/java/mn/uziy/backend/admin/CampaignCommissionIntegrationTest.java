package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;

import java.util.Map;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;

/** The admin sets a paid campaign's commission when approving it, over HTTP and into the database. */
class CampaignCommissionIntegrationTest extends AbstractApiIntegrationTest {

    /** Paid and waiting for approval: 1,000 ₮ per viewer for 1,000 viewers at 30 %. */
    private long pendingPaidCampaign() {
        long id = campaign(company(), "PENDING", "ALL", 0, 100, "ALL");
        jdbc.update("""
                UPDATE campaigns SET cost_per_view = 1000, reward_per_user = 700, target_viewers = 1000,
                    total_budget = 1000000, remaining_budget = 1000000, commission_percent = 30 WHERE id = ?""", id);
        return id;
    }

    private int approve(long campaign, String query) throws Exception {
        return mvc.perform(patch("/admin/campaigns/" + campaign + "/moderate?decision=ACTIVE" + query)
                .header("Authorization", bearer(admin()))).andReturn().getResponse().getStatus();
    }

    private Map<String, Object> row(long campaign) {
        return jdbc.queryForMap("""
                SELECT status, commission_percent, reward_per_user, cost_per_view, total_budget, target_viewers
                FROM campaigns WHERE id = ?""", campaign);
    }

    @Test
    void approvingAt40PercentPaysViewers600AndKeepsThePriceAndReach() throws Exception {
        long id = pendingPaidCampaign();

        assertThat(approve(id, "&commissionPercent=40")).isEqualTo(200);

        Map<String, Object> c = row(id);
        assertThat(c.get("status")).isEqualTo("ACTIVE");
        assertThat(((Number) c.get("commission_percent")).intValue()).isEqualTo(40);
        assertThat(((Number) c.get("reward_per_user")).doubleValue()).isEqualTo(600.0);
        assertThat(((Number) c.get("cost_per_view")).doubleValue()).isEqualTo(1000.0);
        assertThat(((Number) c.get("total_budget")).doubleValue()).isEqualTo(1_000_000.0);
        assertThat(((Number) c.get("target_viewers")).intValue()).isEqualTo(1000);
    }

    @Test
    void approvingWithoutAPercentageKeepsTheCampaignsOwn() throws Exception {
        long id = pendingPaidCampaign();
        assertThat(approve(id, "")).isEqualTo(200);
        assertThat(((Number) row(id).get("reward_per_user")).doubleValue()).isEqualTo(700.0);
    }

    @Test
    void anInvalidPercentageLeavesTheCampaignWaiting() throws Exception {
        long id = pendingPaidCampaign();

        assertThat(approve(id, "&commissionPercent=95")).isEqualTo(400);
        jdbc.update("UPDATE platform_settings SET min_reward_per_viewer = 650");
        try {
            // 40 % would leave the viewer 600 ₮, under the 650 ₮ minimum.
            assertThat(approve(id, "&commissionPercent=40")).isEqualTo(400);
        } finally {
            jdbc.update("UPDATE platform_settings SET min_reward_per_viewer = 100");
        }

        Map<String, Object> c = row(id);
        assertThat(c.get("status")).isEqualTo("PENDING");
        assertThat(((Number) c.get("reward_per_user")).doubleValue()).isEqualTo(700.0);
    }
}
