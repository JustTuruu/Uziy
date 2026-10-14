package mn.uziy.backend.media;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.security.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class CampaignImageIntegrationTest {
    @Container static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");
    @DynamicPropertySource static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
    }
    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @Autowired UserRepository users;
    @Autowired CampaignRepository campaigns;
    @Autowired CampaignImageRepository images;
    private String bearer(long id) { return "Bearer " + jwt.issue(users.findById(id).orElseThrow()); }
    private MockMultipartFile image() throws Exception {
        var out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(32, 18, BufferedImage.TYPE_INT_RGB), "png", out);
        return new MockMultipartFile("file", "cover.png", "image/png", out.toByteArray());
    }
    @Test void adminCanUploadReplaceReadAndRemove() throws Exception {
        long id = 1L;
        double budget = campaigns.findById(id).orElseThrow().getRemainingBudget();
        String path = "/admin/campaigns/" + id + "/image";
        mvc.perform(multipart(path).file(image()).header("Authorization", bearer(1)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.thumbnailUrl").isString());
        String first = campaigns.findById(id).orElseThrow().getThumbnailUrl();
        assertThat(images.find(id)).isPresent();
        mvc.perform(get("/admin/campaigns/" + id).header("Authorization", bearer(1)))
                .andExpect(jsonPath("$.campaign.thumbnailUrl").value(first));
        mvc.perform(get("/public/feed")).andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.id == 1)].thumbnailUrl", org.hamcrest.Matchers.hasItem(first)));
        mvc.perform(get("/viewer/feed").header("Authorization", bearer(100))).andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.id == 1)].thumbnailUrl", org.hamcrest.Matchers.hasItem(first)));
        mvc.perform(get(first)).andExpect(status().isOk()).andExpect(content().contentType("image/png"));
        mvc.perform(multipart(path).file(image()).header("Authorization", bearer(1))).andExpect(status().isOk());
        assertThat(campaigns.findById(id).orElseThrow().getThumbnailUrl()).isNotEqualTo(first);
        assertThat(campaigns.findById(id).orElseThrow().getRemainingBudget()).isEqualTo(budget);
        mvc.perform(delete(path).header("Authorization", bearer(1))).andExpect(status().isOk());
        assertThat(campaigns.findById(id).orElseThrow().getThumbnailUrl()).isNull();
        assertThat(images.find(id)).isEmpty();
        mvc.perform(get(first)).andExpect(status().isNotFound());
    }
    @Test void uploadRequiresAdminAndRealImage() throws Exception {
        long id = 1L;
        String path = "/admin/campaigns/" + id + "/image";
        mvc.perform(multipart(path).file(image())).andExpect(status().isForbidden());
        mvc.perform(multipart(path).file(image()).header("Authorization", bearer(2))).andExpect(status().isForbidden());
        mvc.perform(multipart(path).file(image()).header("Authorization", bearer(100))).andExpect(status().isForbidden());
        mvc.perform(multipart(path).file(new MockMultipartFile("file", "bad.png", "image/png", "not an image".getBytes()))
                .header("Authorization", bearer(1))).andExpect(status().isBadRequest());
        mvc.perform(multipart(path).file(new MockMultipartFile("file", "large.png", "image/png", new byte[5 * 1024 * 1024 + 1]))
                .header("Authorization", bearer(1))).andExpect(status().isBadRequest());
        mvc.perform(multipart("/admin/campaigns/9999999/image").file(image()).header("Authorization", bearer(1)))
                .andExpect(status().isNotFound());
    }
}
