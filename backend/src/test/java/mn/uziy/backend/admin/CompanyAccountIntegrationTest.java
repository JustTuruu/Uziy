package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/**
 * Company accounts are opened by an admin, on Postgres, and the new company can log in with the password handed over
 * (then proves its phone by SMS, like every console account on a new browser).
 */
class CompanyAccountIntegrationTest extends AbstractApiIntegrationTest {

    private ResultActions create(long admin, String name, String phone, String password) throws Exception {
        return mvc.perform(post("/admin/companies").header("Authorization", bearer(admin))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"companyName\":\"%s\",\"phoneNumber\":\"%s\",\"password\":\"%s\"}"
                        .formatted(name, phone, password)));
    }

    @Test
    void anAdminOpensACompanyAccountWhosePasswordWorks() throws Exception {
        String phone = freshPhone();

        create(admin(), "Голомт Банк", phone, "temp-pass1").andExpect(status().isCreated())
                .andExpect(jsonPath("$.companyName").value("Голомт Банк"))
                .andExpect(jsonPath("$.phoneNumber").value(phone))
                .andExpect(jsonPath("$.campaignCount").value(0))
                .andExpect(jsonPath("$.password").doesNotExist());

        mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phoneNumber\":\"%s\",\"password\":\"temp-pass1\"}".formatted(phone)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.role").value("COMPANY"));
    }

    @Test
    void aPhoneThatAlreadyHasAnAccountIs409() throws Exception {
        String viewersPhone = phoneOf(viewer(0));

        create(admin(), "Squat", viewersPhone, "temp-pass1").andExpect(status().isConflict())
                .andExpect(status().reason(CompanyAccountServiceImpl.PHONE_TAKEN));

        assertThat(jdbc.queryForObject("SELECT role FROM users WHERE phone_number = ?", String.class, viewersPhone))
                .isEqualTo("VIEWER");
    }

    @Test
    void anInvalidFormIs400WithAMongolianMessage() throws Exception {
        create(admin(), " ", freshPhone(), "temp-pass1").andExpect(status().isBadRequest())
                .andExpect(status().reason(mn.uziy.backend.common.FieldMessages.COMPANY_NAME_REQUIRED));
        create(admin(), "X", freshPhone(), "ө".repeat(37)).andExpect(status().isBadRequest());
    }

    @Test
    void theListShowsEachCompanyWithItsSurveyCountAndIsLogged() throws Exception {
        long admin = admin();
        long busy = company();
        activeCampaign(busy);
        activeCampaign(busy);
        long quiet = company();

        String body = mvc.perform(get("/admin/companies").header("Authorization", bearer(admin)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();

        List<Map<String, Object>> rows = JsonPath.read(body, "$[?(@.id == %d || @.id == %d)]".formatted(busy, quiet));
        assertThat(rows).extracting(r -> ((Number) r.get("id")).longValue(), r -> ((Number) r.get("campaignCount")).longValue())
                .containsExactlyInAnyOrder(org.assertj.core.groups.Tuple.tuple(busy, 2L),
                        org.assertj.core.groups.Tuple.tuple(quiet, 0L));
        assertThat(JsonPath.<List<String>>read(body, "$[*].phoneNumber")).doesNotContain(phoneOf(admin));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM data_access_log WHERE admin_id = ? AND action = ?",
                Long.class, admin, CompanyAccountServiceImpl.ACTION_LIST)).isEqualTo(1);
    }
}
