package mn.uziy.backend.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;
import tools.jackson.databind.SerializationFeature;
import tools.jackson.databind.json.JsonMapper;

/**
 * The committed {@code docs/api/openapi.json} must describe the API as it is. When a route or DTO changes this
 * test fails; run {@code ./gradlew updateOpenApi}, then regenerate the panel's types
 * ({@code pnpm -C packages/api-types generate}) and run the Flutter contract test.
 */
@TestPropertySource(properties = "springdoc.api-docs.enabled=true")
class OpenApiContractTest extends AbstractApiIntegrationTest {

    static final Path SPEC = Path.of("..", "docs", "api", "openapi.json");
    private static final String UPDATE = "openapi.update";

    /** Keys sorted, two-space indent, trailing newline: a stable file that diffs well in git. */
    private static final JsonMapper STABLE = JsonMapper.builder()
            .enable(SerializationFeature.INDENT_OUTPUT)
            .enable(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS)
            .build();

    @Test
    void theCommittedSpecMatchesTheApi() throws Exception {
        String live = stable(mvc.perform(get("/v3/api-docs").header("Authorization", bearer(admin()))).andReturn().getResponse()
                .getContentAsString(StandardCharsets.UTF_8));

        if (Boolean.getBoolean(UPDATE)) {
            Files.createDirectories(SPEC.getParent());
            Files.writeString(SPEC, live, StandardCharsets.UTF_8);
        }

        assertThat(committed())
                .as("docs/api/openapi.json is out of date — run ./gradlew updateOpenApi")
                .isEqualTo(live);
    }

    @Test
    void onlyAComponentMarkedNullableMayBeNull() {
        assertThat(RequiredResponseFields.nullableComponents(Sample.class)).containsExactly("sometimes");
    }

    @Test
    void aResponseSaysEveryFieldIsSentAndWhichMayBeNull() throws Exception {
        Map<?, ?> me = schema("Me");
        assertThat(strings(me.get("required"))).contains("id", "phoneNumber", "companyName", "district");
        assertThat(String.valueOf(property(me, "companyName").get("type"))).contains("null");
        assertThat(String.valueOf(property(me, "phoneNumber").get("type"))).doesNotContain("null");
    }

    @Test
    void aRecordNestedInARequestIsARequestToo() {
        assertThat(RequiredResponseFields.isRequest(mn.uziy.backend.company.CreateCampaignReq.NewQuestion.class))
                .isTrue();
        assertThat(RequiredResponseFields.isRequest(mn.uziy.backend.auth.Me.class)).isFalse();
    }

    @Test
    void aRequestKeepsItsOwnRequiredFields() throws Exception {
        Map<?, ?> req = schema("CheckQuizAnswerReq");
        assertThat(strings(req.get("required"))).containsExactly("answer");
    }

    record Sample(String always, @org.jspecify.annotations.Nullable String sometimes) {
    }

    private Map<?, ?> schema(String name) throws Exception {
        String json = mvc.perform(get("/v3/api-docs").header("Authorization", bearer(admin()))).andReturn()
                .getResponse().getContentAsString(StandardCharsets.UTF_8);
        Map<?, ?> components = (Map<?, ?>) STABLE.readValue(json, Map.class).get("components");
        return (Map<?, ?>) ((Map<?, ?>) components.get("schemas")).get(name);
    }

    private static java.util.List<String> strings(Object list) {
        return ((java.util.List<?>) list).stream().map(String::valueOf).toList();
    }

    private static Map<?, ?> property(Map<?, ?> schema, String name) {
        return (Map<?, ?>) ((Map<?, ?>) schema.get("properties")).get(name);
    }

    private static String stable(String json) {
        return STABLE.writeValueAsString(STABLE.readValue(json, Map.class)) + "\n";
    }

    private static String committed() throws IOException {
        return Files.exists(SPEC) ? Files.readString(SPEC, StandardCharsets.UTF_8) : "";
    }
}
