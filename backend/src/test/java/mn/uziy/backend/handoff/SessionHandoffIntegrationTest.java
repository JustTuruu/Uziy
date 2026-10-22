package mn.uziy.backend.handoff;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/** On Postgres: an admin's code becomes an admin-panel session exactly once; nobody else can make one. */
class SessionHandoffIntegrationTest extends AbstractApiIntegrationTest {

    private String codeFor(long admin) throws Exception {
        String body = mvc.perform(post("/admin/session-handoffs").header("Authorization", bearer(admin)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.expiresAt").isNotEmpty())
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.code");
    }

    private ResultActions redeem(String code) throws Exception {
        return mvc.perform(post("/auth/session-handoffs/redeem").contentType(MediaType.APPLICATION_JSON)
                .content("{\"code\":\"%s\"}".formatted(code)));
    }

    @Test
    void aCodeGivesTheAdminPanelAWorkingSessionOnce() throws Exception {
        long admin = admin();
        String code = codeFor(admin);

        String body = redeem(code).andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(admin))
                .andExpect(jsonPath("$.user.role").value("ADMIN"))
                .andReturn().getResponse().getContentAsString();
        String token = JsonPath.read(body, "$.token");
        mvc.perform(get("/admin/stats").header("Authorization", "Bearer " + token)).andExpect(status().isOk());

        redeem(code).andExpect(status().isBadRequest())
                .andExpect(status().reason(SessionHandoffServiceImpl.INVALID));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM session_handoffs WHERE code_hash = ?", Long.class, code))
                .isZero();
    }

    @Test
    void anExpiredCodeIsRefused() throws Exception {
        long admin = admin();
        String code = codeFor(admin);
        jdbc.update("UPDATE session_handoffs SET expires_at = now() - INTERVAL '1 second' WHERE user_id = ?", admin);

        redeem(code).andExpect(status().isBadRequest());
    }

    @Test
    void anUnknownCodeIsRefused() throws Exception {
        redeem("not-a-real-code").andExpect(status().isBadRequest())
                .andExpect(status().reason(SessionHandoffServiceImpl.INVALID));
    }

    @Test
    void onlyAnAdminCanAskForACode() throws Exception {
        mvc.perform(post("/admin/session-handoffs").header("Authorization", bearer(company())))
                .andExpect(status().isForbidden());
        mvc.perform(post("/admin/session-handoffs")).andExpect(status().isForbidden());
    }
}
