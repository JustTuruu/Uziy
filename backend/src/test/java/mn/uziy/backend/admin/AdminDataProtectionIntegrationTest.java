package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.List;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;

/**
 * Admin reads of personal data leave a trace in data_access_log, and the payout history shows decided requests'
 * bank accounts masked — the pending queue keeps the whole number because it is needed to send the money.
 */
class AdminDataProtectionIntegrationTest extends AbstractApiIntegrationTest {

    private long payout(long viewer, String status) {
        return jdbc.queryForObject("""
                INSERT INTO payout_requests (user_id, amount, bank, account_number, account_name, status, decided_at)
                VALUES (?, 5000, 'Khan Bank', '5001234567', 'БОЛД', ?, CASE WHEN ? = 'PENDING' THEN NULL ELSE now() END)
                RETURNING id""", Long.class, viewer, status, status);
    }

    private String getAs(long admin, String path) throws Exception {
        return mvc.perform(get(path).header("Authorization", bearer(admin)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
    }

    private List<String> logOf(long admin) {
        return jdbc.queryForList("SELECT action || ':' || detail FROM data_access_log WHERE admin_id = ? ORDER BY id",
                String.class, admin);
    }

    @Test
    void decidedPayoutsShowOnlyTheLastFourDigitsButPendingOnesShowAll() throws Exception {
        long admin = admin();
        long viewer = viewer(0);
        long pending = payout(viewer, "PENDING");
        long approved = payout(viewer, "APPROVED");
        long rejected = payout(viewer, "REJECTED");

        String queue = getAs(admin, "/admin/payouts");
        String history = getAs(admin, "/admin/payouts/history");

        assertThat(JsonPath.<List<String>>read(queue, "$[?(@.id == %d)].accountNumber".formatted(pending)))
                .containsExactly("5001234567");
        assertThat(JsonPath.<List<String>>read(history,
                "$[?(@.id == %d || @.id == %d)].accountNumber".formatted(approved, rejected)))
                .containsExactly("•••• 4567", "•••• 4567");
        assertThat(history).doesNotContain("5001234567");
    }

    @Test
    void everyAdminReadOfPeopleOrPayoutsIsInTheAccessLog() throws Exception {
        long admin = admin();
        long viewer = viewer(0);

        getAs(admin, "/admin/users");
        getAs(admin, "/admin/users/" + viewer);
        getAs(admin, "/admin/payouts");
        getAs(admin, "/admin/payouts/history");

        assertThat(logOf(admin)).containsExactly("VIEW_USERS:", "VIEW_USER:user=" + viewer, "VIEW_PAYOUTS:",
                "VIEW_PAYOUT_HISTORY:");
    }

    @Test
    void aLookUpOfAMissingUserIsNotLogged() throws Exception {
        long admin = admin();

        mvc.perform(get("/admin/users/99999999").header("Authorization", bearer(admin)))
                .andExpect(status().isNotFound());

        assertThat(logOf(admin)).isEmpty();
    }
}
