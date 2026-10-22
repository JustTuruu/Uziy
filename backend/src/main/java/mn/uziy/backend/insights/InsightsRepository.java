package mn.uziy.backend.insights;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import mn.uziy.backend.privacy.StatisticsConsentService;
import org.jspecify.annotations.Nullable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Pattern: Repository — read-only access for anonymous statistics. Every query that touches people is limited to
 * consenting viewers ({@link #CONSENTING}) and reads only gender, birth date and city: never a name, phone,
 * district, balance or id.
 */
@Repository
public class InsightsRepository {

    /**
     * The one consent filter; every person-level query below uses it: viewers who said yes to the CURRENT
     * wording AND are adults ({@link StatisticsPrivacyPolicy#MIN_AGE}) — a minor's yes is not enough. A yes to an
     * older wording reads as "not asked" in the app, so it must not count here either (audit 2026-10-22).
     */
    static final String CONSENTING = "u.role = 'VIEWER' AND u.stats_consent = 'GRANTED'"
            + " AND u.stats_consent_version = '" + StatisticsConsentService.CURRENT_VERSION + "'"
            + " AND u.birth_date <= CURRENT_DATE - INTERVAL '" + StatisticsPrivacyPolicy.MIN_AGE + " years'";

    /** What the statistics may know about a person. */
    public record Person(@Nullable String gender, @Nullable LocalDate birthDate, @Nullable String city) {
    }

    /** One answer with its person's groups. */
    public record Answer(String answerJson, Person person) {
    }

    public record Question(long id, String prompt, String type, String optionsJson, String surveyTitle,
                           String companyName) {
    }

    public record QuestionCount(long id, String prompt, String type, String surveyTitle, String companyName,
                                long respondents) {
    }

    private final JdbcTemplate jdbc;

    public InsightsRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long viewers() {
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE role = 'VIEWER'", Long.class);
        return n == null ? 0 : n;
    }

    public List<Person> consentingViewers() {
        return jdbc.query("SELECT u.gender, u.birth_date, u.city FROM users u WHERE " + CONSENTING,
                (rs, row) -> new Person(rs.getString(1), rs.getObject(2, LocalDate.class), rs.getString(3)));
    }

    /** Choice and rating questions with how many consenting viewers answered each, most answered first. */
    public List<QuestionCount> questionCounts() {
        return jdbc.query("""
                SELECT q.id, q.prompt, q.q_type, c.title, COALESCE(comp.company_name, ''),
                       COUNT(r.id) FILTER (WHERE %s) AS respondents
                FROM survey_questions q
                JOIN campaigns c ON c.id = q.campaign_id
                JOIN users comp ON comp.id = c.company_id
                LEFT JOIN survey_responses r ON r.question_id = q.id
                LEFT JOIN view_history v ON v.id = r.view_id
                LEFT JOIN users u ON u.id = v.user_id
                WHERE q.q_type <> 'TEXT'
                GROUP BY q.id, q.prompt, q.q_type, c.title, comp.company_name
                ORDER BY respondents DESC, q.id DESC""".formatted(CONSENTING),
                (rs, row) -> new QuestionCount(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4),
                        rs.getString(5), rs.getLong(6)));
    }

    public Optional<Question> question(long id) {
        return jdbc.query("""
                SELECT q.id, q.prompt, q.q_type, q.options_json::text, c.title, COALESCE(comp.company_name, '')
                FROM survey_questions q
                JOIN campaigns c ON c.id = q.campaign_id
                JOIN users comp ON comp.id = c.company_id
                WHERE q.id = ?""",
                (rs, row) -> new Question(rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4),
                        rs.getString(5), rs.getString(6)), id).stream().findFirst();
    }

    /** The consenting viewers' answers to one question. */
    public List<Answer> answers(long questionId) {
        return jdbc.query("""
                SELECT r.answer_json::text, u.gender, u.birth_date, u.city
                FROM survey_responses r
                JOIN view_history v ON v.id = r.view_id
                JOIN users u ON u.id = v.user_id
                WHERE r.question_id = ? AND %s""".formatted(CONSENTING),
                (rs, row) -> new Answer(rs.getString(1),
                        new Person(rs.getString(2), rs.getObject(3, LocalDate.class), rs.getString(4))),
                questionId);
    }
}
