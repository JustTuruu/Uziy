package mn.uziy.backend.company;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.security.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * A company's own survey cover over real HTTP, security and Postgres. Uses the seeded companies MobiCom (id 2)
 * and Golomt Bank (id 3); each test creates its own survey.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class CompanyCampaignImageIntegrationTest {

    private static final long MOBICOM = 2L;
    private static final long GOLOMT = 3L;

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @Autowired UserRepository users;
    @Autowired CampaignRepository campaigns;
    @Autowired JdbcTemplate jdbc;

    private String bearer(long userId) {
        return "Bearer " + jwt.issue(users.findById(userId).orElseThrow());
    }

    private static MockMultipartFile png() throws Exception {
        var out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(32, 18, BufferedImage.TYPE_INT_RGB), "png", out);
        return new MockMultipartFile("file", "cover.png", "image/png", out.toByteArray());
    }

    /** A new survey-only campaign of {@code company}, still awaiting payment. */
    private long newSurvey(long company) throws Exception {
        String body = mvc.perform(post("/company/campaigns").header("Authorization", bearer(company))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Зургийн туршилт","hasVideo":false,"durationSeconds":0,
                                 "targetGender":"ALL","minAge":18,"maxAge":45,"targetCity":"ALL",
                                 "rewardPerUser":500,"totalBudget":100000,
                                 "questions":[{"prompt":"Таалагдсан уу?","type":"SINGLE_CHOICE",
                                               "options":["Тийм","Үгүй"]}]}"""))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.id")).longValue();
    }

    private static String path(long id) {
        return "/company/campaigns/" + id + "/image";
    }

    @Test
    void theOwnerSetsTheCoverBeforeApprovalAndTheAppCanLoadIt() throws Exception {
        long id = newSurvey(MOBICOM);

        String body = mvc.perform(multipart(path(id)).file(png()).header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.thumbnailUrl").isString())
                .andReturn().getResponse().getContentAsString();
        String url = JsonPath.read(body, "$.thumbnailUrl");

        assertThat(campaigns.findById(id).orElseThrow().getThumbnailUrl()).isEqualTo(url);
        mvc.perform(get("/company/campaigns/" + id).header("Authorization", bearer(MOBICOM)))
                .andExpect(jsonPath("$.thumbnailUrl").value(url));
        mvc.perform(get(url)).andExpect(status().isOk()).andExpect(content().contentType("image/png"));

        mvc.perform(delete(path(id)).header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.thumbnailUrl").doesNotExist());
        assertThat(campaigns.findById(id).orElseThrow().getThumbnailUrl()).isNull();
    }

    @Test
    void anotherCompanyCannotTouchTheCover() throws Exception {
        long id = newSurvey(MOBICOM);

        mvc.perform(multipart(path(id)).file(png()).header("Authorization", bearer(GOLOMT)))
                .andExpect(status().isForbidden());
        mvc.perform(delete(path(id)).header("Authorization", bearer(GOLOMT)))
                .andExpect(status().isForbidden());
        assertThat(campaigns.findById(id).orElseThrow().getThumbnailUrl()).isNull();
    }

    @Test
    void afterApprovalOnlyAnAdminMayChangeIt() throws Exception {
        long id = newSurvey(MOBICOM);
        jdbc.update("UPDATE campaigns SET status = ? WHERE id = ?", CampaignStatus.ACTIVE.name(), id);

        mvc.perform(multipart(path(id)).file(png()).header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isConflict());
        mvc.perform(delete(path(id)).header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isConflict());
    }

    @Test
    void aViewerOrAGuestIsTurnedAwayAndAFakeImageIsRefused() throws Exception {
        long id = newSurvey(MOBICOM);

        mvc.perform(multipart(path(id)).file(png())).andExpect(status().isForbidden());
        mvc.perform(multipart(path(id)).file(png()).header("Authorization", bearer(100)))
                .andExpect(status().isForbidden());
        mvc.perform(multipart(path(id))
                        .file(new MockMultipartFile("file", "x.png", "image/png", "not an image".getBytes()))
                        .header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isBadRequest());
    }
}
