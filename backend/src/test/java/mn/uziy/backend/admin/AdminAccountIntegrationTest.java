package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.List;
import mn.uziy.backend.common.FieldMessages;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/** Admin accounts are opened by an admin, on Postgres; the new admin still has to pass the SMS step to log in. */
class AdminAccountIntegrationTest extends AbstractApiIntegrationTest {

    private ResultActions create(long admin, String phone, String password) throws Exception {
        return mvc.perform(post("/admin/admins").header("Authorization", bearer(admin))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"phoneNumber\":\"%s\",\"password\":\"%s\"}".formatted(phone, password)));
    }

    @Test
    void anAdminOpensAnAdminAccountWhosePasswordLeadsToTheSmsStep() throws Exception {
        String phone = freshPhone();

        create(admin(), phone, "temp-pass1").andExpect(status().isCreated())
                .andExpect(jsonPath("$.phoneNumber").value(phone))
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        assertThat(jdbc.queryForObject("SELECT role FROM users WHERE phone_number = ?", String.class, phone))
                .isEqualTo("ADMIN");
        mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phoneNumber\":\"%s\",\"password\":\"temp-pass1\"}".formatted(phone)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.role").value("ADMIN"));
    }

    @Test
    void aPhoneThatAlreadyHasAnAccountIs409AndKeepsItsRole() throws Exception {
        String viewersPhone = phoneOf(viewer(0));

        create(admin(), viewersPhone, "temp-pass1").andExpect(status().isConflict())
                .andExpect(status().reason(AdminAccountServiceImpl.PHONE_TAKEN));

        assertThat(jdbc.queryForObject("SELECT role FROM users WHERE phone_number = ?", String.class, viewersPhone))
                .isEqualTo("VIEWER");
    }

    @Test
    void anInvalidFormIs400WithAMongolianMessage() throws Exception {
        create(admin(), "8811", "temp-pass1").andExpect(status().isBadRequest())
                .andExpect(status().reason(FieldMessages.PHONE));
        create(admin(), freshPhone(), "ө".repeat(37)).andExpect(status().isBadRequest());
    }

    @Test
    void theListShowsAdminsOnlyAndIsLogged() throws Exception {
        long admin = admin();
        long other = admin();
        long company = company();

        String body = mvc.perform(get("/admin/admins").header("Authorization", bearer(admin)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();

        List<Number> ids = JsonPath.read(body, "$[*].id");
        assertThat(ids).extracting(Number::longValue).contains(admin, other).doesNotContain(company);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM data_access_log WHERE admin_id = ? AND action = ?",
                Long.class, admin, AdminAccountServiceImpl.ACTION_LIST)).isEqualTo(1);
    }
}
