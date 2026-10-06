package mn.uziy.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.jspecify.annotations.Nullable;

/** One survey question of a campaign. {@code optionsJson} is a JSON array of option strings, stored as JSONB. */
@Entity
@Table(name = "survey_questions")
public class SurveyQuestionEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "campaign_id", nullable = false)
    private long campaignId = 0;

    @Column(nullable = false)
    private int position = 0;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String prompt = "";

    @Column(name = "q_type", nullable = false, length = 20)
    private String qType = "SINGLE_CHOICE";

    /** JSON array of option strings, stored as JSONB. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "options_json", nullable = false, columnDefinition = "jsonb")
    private String optionsJson = "[]";

    @Column(nullable = false)
    private boolean required = true;

    public SurveyQuestionEntity() {
    }

    public @Nullable Long getId() { return id; }
    public void setId(@Nullable Long id) { this.id = id; }

    public long getCampaignId() { return campaignId; }
    public void setCampaignId(long campaignId) { this.campaignId = campaignId; }

    public int getPosition() { return position; }
    public void setPosition(int position) { this.position = position; }

    public String getPrompt() { return prompt; }
    public void setPrompt(String prompt) { this.prompt = prompt; }

    public String getQType() { return qType; }
    public void setQType(String qType) { this.qType = qType; }

    public String getOptionsJson() { return optionsJson; }
    public void setOptionsJson(String optionsJson) { this.optionsJson = optionsJson; }

    public boolean isRequired() { return required; }
    public void setRequired(boolean required) { this.required = required; }
}
