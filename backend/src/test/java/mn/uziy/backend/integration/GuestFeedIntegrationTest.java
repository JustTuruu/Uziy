package mn.uziy.backend.integration;

import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.lessThanOrEqualTo;
import static org.hamcrest.Matchers.emptyString;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import mn.uziy.backend.guest.GuestFeedService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** The guest feed over real HTTP security and a real Postgres: open without a token, never leaks videos. */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class GuestFeedIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_guest_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;

    @Test
    void publicFeedIsOpenWithoutATokenAndNeverExposesVideoUrls() throws Exception {
        jdbc.update("UPDATE campaigns SET status = 'ACTIVE', video_url = 'https://cdn.test/x.m3u8'");

        mvc.perform(get("/public/feed"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(lessThanOrEqualTo(GuestFeedService.SAMPLE_SIZE))))
                .andExpect(jsonPath("$[*].videoUrl", everyItem(emptyString())));
    }

    @Test
    void theViewerFeedStaysClosedWithoutAToken() throws Exception {
        int status = mvc.perform(get("/viewer/feed")).andReturn().getResponse().getStatus();

        org.assertj.core.api.Assertions.assertThat(status).isIn(401, 403);
    }
}
