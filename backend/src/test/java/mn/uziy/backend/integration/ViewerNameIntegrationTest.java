package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import mn.uziy.backend.common.FieldMessages;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/** PUT /viewer/me/name: an account from before names were asked gets its овог + нэр, once. */
class ViewerNameIntegrationTest extends AbstractApiIntegrationTest {

    private ResultActions setName(long viewer, String lastName, String firstName) throws Exception {
        return mvc.perform(put("/viewer/me/name")
                .header("Authorization", bearer(viewer))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"lastName\":\"%s\",\"firstName\":\"%s\"}".formatted(lastName, firstName)));
    }

    private String nameInDb(long viewer) {
        return jdbc.queryForObject(
                "SELECT COALESCE(first_name, '') || '|' || COALESCE(last_name, '') FROM users WHERE id = ?",
                String.class, viewer);
    }

    @Test
    void anOlderAccountAddsItsNameAndMeReturnsIt() throws Exception {
        long viewer = viewer(0); // inserted without names, like accounts made before 2026-10-14

        setName(viewer, " Оюун-Эрдэнэ ", "Төрболд")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lastName").value("Оюун-Эрдэнэ"))
                .andExpect(jsonPath("$.firstName").value("Төрболд"));

        mvc.perform(get("/viewer/me").header("Authorization", bearer(viewer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lastName").value("Оюун-Эрдэнэ"))
                .andExpect(jsonPath("$.firstName").value("Төрболд"));
    }

    @Test
    void theNameIsSetOnlyOnce() throws Exception {
        long viewer = viewer(0);
        setName(viewer, "Бат", "Сараа").andExpect(status().isOk());

        // Errors go out through sendError; MockMvc keeps the text as the error message.
        assertThat(setName(viewer, "Өөр", "Хүн")
                .andExpect(status().isConflict())
                .andReturn().getResponse().getErrorMessage()).isEqualTo(Messages.NAME_ALREADY_SET);
        assertThat(nameInDb(viewer)).isEqualTo("Сараа|Бат");
    }

    @Test
    void anAccountRegisteredWithANameCannotChangeIt() throws Exception {
        long viewer = viewer(0);
        jdbc.update("UPDATE users SET last_name = 'Бат', first_name = 'Болд' WHERE id = ?", viewer);

        setName(viewer, "Өөр", "Хүн").andExpect(status().isConflict());
        assertThat(nameInDb(viewer)).isEqualTo("Болд|Бат");
    }

    @Test
    void theRegistrationRulesApply() throws Exception {
        long viewer = viewer(0);

        assertThat(setName(viewer, "Бат123", "Сараа")
                .andExpect(status().isBadRequest())
                .andReturn().getResponse().getErrorMessage()).isEqualTo(FieldMessages.NAME_LETTERS);
        // A blank name breaks two rules at once (required + letters); either message may come first.
        assertThat(setName(viewer, "Бат", " ")
                .andExpect(status().isBadRequest())
                .andReturn().getResponse().getErrorMessage())
                .isIn(FieldMessages.FIRST_NAME_REQUIRED, FieldMessages.NAME_LETTERS);
        assertThat(nameInDb(viewer)).isEqualTo("|");
    }
}
