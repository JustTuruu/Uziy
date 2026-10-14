package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

/**
 * Anonymous statistics end to end on Postgres: only consenting viewers count, small groups stay hidden, free text
 * never shows, only the super admin gets in, and every look is in the access log. Each test builds its own survey
 * and people, so other tests' rows never change the numbers asserted here.
 */
class InsightsIntegrationTest extends AbstractApiIntegrationTest {

    /** A viewer without bcrypt (fast); consent GRANTED, DECLINED or null. */
    private long person(String gender, String birthDate, String city, String consent) {
        return jdbc.queryForObject("""
                INSERT INTO users (phone_number, password_hash, role, gender, birth_date, city, stats_consent,
                                   stats_consent_at, stats_consent_version)
                VALUES (?, 'x', 'VIEWER', ?, CAST(? AS date), ?, ?, ?, ?)
                RETURNING id""", Long.class, freshPhone(), gender, birthDate, city, consent,
                consent == null ? null : java.time.OffsetDateTime.now(),
                consent == null ? null : "2026-10-14");
    }

    private void answer(long viewer, long campaign, long question, String answerJson) {
        Long view = jdbc.queryForObject(
                "INSERT INTO view_history (user_id, campaign_id, reward_paid) VALUES (?, ?, 70) RETURNING id",
                Long.class, viewer, campaign);
        jdbc.update("INSERT INTO survey_responses (view_id, question_id, answer_json) VALUES (?, ?, CAST(? AS jsonb))",
                view, question, answerJson);
    }

    /** 60 consenting women say Тийм, 40 who never agreed say Үгүй, 10 who declined say Үгүй. */
    private long[] surveyWithAnswers() {
        long campaign = activeCampaign(company());
        long choice = question(campaign, 1, "SINGLE_CHOICE", "[\"Тийм\",\"Үгүй\"]", true);
        long text = question(campaign, 2, "TEXT", "[]", false);
        for (int i = 0; i < 60; i++) {
            answer(person("FEMALE", "1995-05-05", "Ховд", "GRANTED"), campaign, choice, "\"Тийм\"");
        }
        for (int i = 0; i < 40; i++) {
            answer(person("MALE", "1990-01-01", "Увс", null), campaign, choice, "\"Үгүй\"");
        }
        for (int i = 0; i < 10; i++) {
            answer(person("MALE", "1990-01-01", "Увс", "DECLINED"), campaign, choice, "\"Үгүй\"");
        }
        return new long[] {choice, text};
    }

    private long logRows(long adminId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM data_access_log WHERE admin_id = ?", Long.class, adminId);
    }

    @Test
    void onlyConsentingViewersAreCounted() throws Exception {
        long admin = admin();
        long q = surveyWithAnswers()[0];

        mvc.perform(get("/admin/insights/questions/" + q).header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.suppressed").value(false))
                .andExpect(jsonPath("$.people").value(60))
                .andExpect(jsonPath("$.shares[0].option").value("Тийм"))
                .andExpect(jsonPath("$.shares[0].percent").value(100))
                .andExpect(jsonPath("$.shares[1].percent").value(0));
    }

    @Test
    void aNarrowGroupIsHiddenAndTheResponseNamesNobody() throws Exception {
        long admin = admin();
        long q = surveyWithAnswers()[0];

        String body = mvc.perform(get("/admin/insights/questions/" + q).param("ageBand", "18–24")
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.suppressed").value(true))
                .andExpect(jsonPath("$.people").doesNotExist())
                .andExpect(jsonPath("$.shares").isEmpty())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
        assertThat(body).doesNotContain("phone", "birth", "Ховд\"", "name");
    }

    @Test
    void aMinorsYesIsNotEnough() throws Exception {
        long admin = admin();
        long campaign = activeCampaign(company());
        long q = question(campaign, 1, "SINGLE_CHOICE", "[\"Тийм\",\"Үгүй\"]", true);
        String sixteen = java.time.LocalDate.now().minusYears(16).toString();
        for (int i = 0; i < 60; i++) {
            answer(person("FEMALE", sixteen, "Ховд", "GRANTED"), campaign, q, "\"Тийм\"");
        }

        mvc.perform(get("/admin/insights/questions/" + q).header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.suppressed").value(true));
    }

    @Test
    void freeTextIsRefused() throws Exception {
        long admin = admin();
        long text = surveyWithAnswers()[1];

        mvc.perform(get("/admin/insights/questions/" + text).header("Authorization", bearer(admin)))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/admin/insights/questions/" + text + "/export.csv").header("Authorization", bearer(admin)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void theExportIsACsvAndEveryLookIsLogged() throws Exception {
        long admin = admin();
        long q = surveyWithAnswers()[0];
        long before = logRows(admin);

        String csv = mvc.perform(get("/admin/insights/questions/" + q + "/export.csv")
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
        mvc.perform(get("/admin/insights/overview").header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.minGroupSize").value(50));

        assertThat(csv).contains("\"Бүх оролцогч\",\"60\",\"100%\",\"0%\"");
        assertThat(logRows(admin)).isEqualTo(before + 2);
        mvc.perform(get("/admin/insights/access-log").header("Authorization", bearer(admin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].action").value("VIEW_ACCESS_LOG"))
                .andExpect(jsonPath("$[1].action").value("VIEW_OVERVIEW"))
                .andExpect(jsonPath("$[2].action").value("EXPORT_CSV"));
    }

    @Test
    void onlyTheSuperAdminGetsIn() throws Exception {
        long q = surveyWithAnswers()[0];
        for (long user : new long[] {company(), viewer(0)}) {
            mvc.perform(get("/admin/insights/questions/" + q).header("Authorization", bearer(user)))
                    .andExpect(status().isForbidden());
        }
        mvc.perform(get("/admin/insights/overview")).andExpect(status().isForbidden());
    }

    @Test
    void aViewerGivesAndWithdrawsConsentAndCountsOnlyWhileItHolds() throws Exception {
        long viewer = viewer(0);

        mvc.perform(get("/viewer/consents/statistics").header("Authorization", bearer(viewer)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UNASKED"));

        mvc.perform(put("/viewer/consents/statistics").header("Authorization", bearer(viewer))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"granted\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("GRANTED"));
        assertThat(jdbc.queryForObject("SELECT stats_consent FROM users WHERE id = ?", String.class, viewer))
                .isEqualTo("GRANTED");

        mvc.perform(put("/viewer/consents/statistics").header("Authorization", bearer(viewer))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"granted\":false}"))
                .andExpect(jsonPath("$.status").value("DECLINED"));
        assertThat(jdbc.queryForObject("SELECT stats_consent FROM users WHERE id = ?", String.class, viewer))
                .isEqualTo("DECLINED");

        mvc.perform(put("/viewer/consents/statistics").header("Authorization", bearer(viewer))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
    }
}
