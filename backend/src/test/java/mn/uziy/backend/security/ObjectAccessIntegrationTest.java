package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

/**
 * Insecure direct object references: ids are guessable numbers, so every route that takes one must check
 * the caller is allowed that particular object — not just that the caller has the right role.
 */
class ObjectAccessIntegrationTest extends AbstractApiIntegrationTest {

    private int status(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,
                       long as) throws Exception {
        return mvc.perform(request.header("Authorization", bearer(as))).andReturn().getResponse().getStatus();
    }

    private String body(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,
                        long as) throws Exception {
        return mvc.perform(request.header("Authorization", bearer(as))).andReturn().getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
    }

    @Test
    void aCompanyCannotReadAnotherCompanysCampaign() throws Exception {
        long owner = company();
        long intruder = company();
        long campaign = activeCampaign(owner);

        assertThat(status(get("/company/campaigns/" + campaign), owner)).isEqualTo(200);
        assertThat(status(get("/company/campaigns/" + campaign), intruder)).isIn(403, 404);
    }

    @Test
    void aCompanyCannotChangeThePauseStateOfAnotherCompanysCampaign() throws Exception {
        long owner = company();
        long intruder = company();
        long campaign = activeCampaign(owner);

        assertThat(status(patch("/company/campaigns/" + campaign + "/status").param("status", "PAUSED"), intruder))
                .isIn(403, 404);
        assertThat(jdbc.queryForObject("SELECT status FROM campaigns WHERE id = ?", String.class, campaign))
                .isEqualTo("ACTIVE");
    }

    @Test
    void aCompanyCannotPayForAnotherCompanysCampaign() throws Exception {
        long owner = company();
        long intruder = company();
        long campaign = campaign(owner, "AWAITING_PAYMENT", "ALL", 0, 100, "ALL");
        jdbc.update("UPDATE campaigns SET paid_at = NULL WHERE id = ?", campaign);

        assertThat(status(post("/company/campaigns/" + campaign + "/pay"), intruder)).isIn(403, 404);
        assertThat(jdbc.queryForObject("SELECT status FROM campaigns WHERE id = ?", String.class, campaign))
                .isEqualTo("AWAITING_PAYMENT");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM campaign_payments WHERE campaign_id = ?",
                Long.class, campaign)).isZero();
    }

    @Test
    void aCompanyCannotSeeAnotherCompanysAnalytics() throws Exception {
        long owner = company();
        long intruder = company();
        long campaign = activeCampaign(owner);

        assertThat(status(get("/company/analytics").param("campaignId", String.valueOf(campaign)), intruder))
                .isEqualTo(404);
        String text = body(get("/company/analytics"), intruder);
        assertThat(text).doesNotContain("\"campaignId\":" + campaign);
    }

    @Test
    void aCompanysListNeverContainsAnotherCompanysCampaigns() throws Exception {
        long owner = company();
        long other = company();
        long mine = activeCampaign(owner);
        long theirs = activeCampaign(other);

        String text = body(get("/company/campaigns"), owner);

        assertThat(text).contains("\"id\":" + mine).doesNotContain("\"id\":" + theirs + ",");
    }

    @Test
    void aViewerSeesOnlyTheirOwnPayoutsAndHistory() throws Exception {
        long alice = viewer(0);
        long bob = viewer(0);
        jdbc.update("""
                INSERT INTO payout_requests (user_id, amount, bank, account_number, account_name)
                VALUES (?, 777, 'Khan Bank', 'SECRET-ACCOUNT', 'Bob Secret')""", bob);

        String alicesView = body(get("/viewer/payouts"), alice);

        assertThat(alicesView).doesNotContain("SECRET-ACCOUNT").doesNotContain("Bob Secret").doesNotContain("777");
        assertThat(body(get("/viewer/payouts"), bob)).contains("SECRET-ACCOUNT");
    }

    @Test
    void aViewerCannotRegisterTheirDeviceTokenOverSomeoneElsesAndThenUnregisterIt() throws Exception {
        long alice = viewer(0);
        long bob = viewer(0);
        mvc.perform(post("/viewer/devices").contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"shared-token-xyz\",\"platform\":\"ANDROID\"}")
                .header("Authorization", bearer(alice))).andReturn();

        // Bob tries to delete Alice's token: it must not remove her registration.
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/viewer/devices")
                .param("token", "shared-token-xyz").header("Authorization", bearer(bob))).andReturn();

        Long aliceRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM device_tokens WHERE token = 'shared-token-xyz' AND user_id = ?", Long.class, alice);
        assertThat(aliceRows).as("Alice's device registration survives Bob's delete").isEqualTo(1L);
    }

    @Test
    void aViewerCannotReadTheQuestionsOfACampaignThatIsNotLiveYet() throws Exception {
        long company = company();
        long draft = campaign(company, "PENDING", "ALL", 0, 100, "ALL");
        question(draft, 1, "TEXT", "[]", true);

        String text = body(get("/viewer/campaigns/" + draft + "/questions"), viewer(0));

        assertThat(text).as("unreleased survey questions must not leak to viewers").doesNotContain("\"prompt\"");
    }

    @Test
    void anAdminDecisionOnAMissingPayoutIsA404NotACrash() throws Exception {
        long admin = admin();

        assertThat(status(patch("/admin/payouts/987654321/decision").param("decision", "APPROVED"), admin))
                .isEqualTo(404);
    }

    @Test
    void aMissingUserOrCampaignIsA404NotACrash() throws Exception {
        long admin = admin();

        assertThat(status(get("/admin/users/987654321"), admin)).isEqualTo(404);
        assertThat(status(get("/admin/campaigns/987654321"), admin)).isEqualTo(404);
        assertThat(status(patch("/admin/users/987654321/verify"), admin)).isEqualTo(404);
        assertThat(status(patch("/admin/campaigns/987654321/moderate").param("decision", "ACTIVE"), admin))
                .isEqualTo(404);
    }
}
