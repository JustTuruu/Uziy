package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Date;
import javax.crypto.SecretKey;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

/** What an attacker with a forged, stale or odd credential — or just curiosity — can get. */
class TokenAndExposureIntegrationTest extends AbstractApiIntegrationTest {

    private static final String OTHER_SECRET = "an-attackers-own-secret-that-is-long-enough-for-hs512-0123456789";

    private int statusWith(String path, String authorization) throws Exception {
        var request = get(path);
        if (authorization != null) {
            request.header("Authorization", authorization);
        }
        return mvc.perform(request).andReturn().getResponse().getStatus();
    }

    private SecretKey key(String secret) {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    private String forged(String secret, long userId, String role, Date expires) {
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("role", role)
                .issuedAt(new Date())
                .expiration(expires)
                .signWith(key(secret))
                .compact();
    }

    private static Date inOneHour() {
        return new Date(System.currentTimeMillis() + 3_600_000);
    }

    // ------- forged and broken tokens ---------------------------------------

    @Test
    void anUnsignedTokenClaimingToBeAdminIsRefused() throws Exception {
        String unsigned = Jwts.builder().subject("1").claim("role", "ADMIN").expiration(inOneHour()).compact();

        assertThat(statusWith("/admin/stats", "Bearer " + unsigned)).isIn(401, 403);
    }

    @Test
    void aTokenSignedWithSomeoneElsesSecretIsRefused() throws Exception {
        long admin = admin();

        String forged = forged(OTHER_SECRET, admin, "ADMIN", inOneHour());

        assertThat(statusWith("/admin/stats", "Bearer " + forged)).isIn(401, 403);
    }

    @Test
    void anExpiredTokenIsRefused() throws Exception {
        long admin = admin();
        // Signed with the real key through the service's own signing, then aged by editing nothing: build an expired one with the
        // real secret read from a legitimately issued token's signature algorithm is impossible, so use the real key via the service.
        String valid = tokenOf(admin);

        assertThat(statusWith("/admin/stats", "Bearer " + valid)).isEqualTo(200);
        String expired = forgedWithServiceKey(admin, "ADMIN", new Date(System.currentTimeMillis() - 1000));

        assertThat(statusWith("/admin/stats", "Bearer " + expired)).isIn(401, 403);
    }

    /** A token signed with the real key, so only its expiry (or role) is wrong. */
    private String forgedWithServiceKey(long userId, String role, Date expires) {
        String secret = serviceSecret();
        return forged(secret, userId, role, expires);
    }

    @org.springframework.beans.factory.annotation.Value("${uziy.jwt.secret}")
    private String configuredSecret;

    private String serviceSecret() {
        return configuredSecret;
    }

    @Test
    void editingTheRoleInsideAValidTokenBreaksItsSignature() throws Exception {
        long viewer = viewer(0);
        String[] parts = tokenOf(viewer).split("\\.");
        String payload = new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8)
                .replace("\"VIEWER\"", "\"ADMIN\"");
        String tampered = parts[0] + "."
                + Base64.getUrlEncoder().withoutPadding().encodeToString(payload.getBytes(StandardCharsets.UTF_8))
                + "." + parts[2];

        assertThat(statusWith("/admin/stats", "Bearer " + tampered)).isIn(401, 403);
    }

    @Test
    void swappingTheAlgorithmHeaderToNoneIsRefused() throws Exception {
        long admin = admin();
        String[] parts = tokenOf(admin).split("\\.");
        String none = Base64.getUrlEncoder().withoutPadding()
                .encodeToString("{\"alg\":\"none\",\"typ\":\"JWT\"}".getBytes(StandardCharsets.UTF_8));

        assertThat(statusWith("/admin/stats", "Bearer " + none + "." + parts[1] + ".")).isIn(401, 403);
        assertThat(statusWith("/admin/stats", "Bearer " + none + "." + parts[1] + "." + parts[2])).isIn(401, 403);
    }

    @ParameterizedTest
    @ValueSource(strings = {"Bearer", "Bearer ", "Bearer not.a.token", "Bearer null", "Basic YWRtaW46YWRtaW4=",
            "bearer abc", "Token abc", "Bearer a.b", "Bearer ...."})
    void garbageAuthorizationHeadersAreTreatedAsAnonymous(String header) throws Exception {
        assertThat(statusWith("/viewer/me", header)).isIn(401, 403);
    }

    @Test
    void aTokenWhoseRoleIsNotARealRoleIsRefused() throws Exception {
        long viewer = viewer(0);

        assertThat(statusWith("/viewer/me", "Bearer " + forgedWithServiceKey(viewer, "SUPERADMIN", inOneHour())))
                .isIn(401, 403);
    }

    // ------- stale credentials ----------------------------------------------

    @Test
    void aValidTokenOfAUserWhoNoLongerExistsIsRefusedNotACrash() throws Exception {
        long viewer = viewer(0);
        String token = tokenOf(viewer);
        jdbc.update("DELETE FROM users WHERE id = ?", viewer);

        assertThat(statusWith("/viewer/me", "Bearer " + token)).as("deleted user").isIn(401, 403);
    }

    @Test
    void aTokenKeepsNoPowerAfterTheUsersRoleIsChanged() throws Exception {
        long admin = admin();
        String token = tokenOf(admin);
        assertThat(statusWith("/admin/stats", "Bearer " + token)).isEqualTo(200);

        jdbc.update("UPDATE users SET role = 'VIEWER' WHERE id = ?", admin);

        assertThat(statusWith("/admin/stats", "Bearer " + token)).as("demoted admin").isIn(401, 403);
    }

    // ------- response hygiene -----------------------------------------------

    private String body(MvcResult r) throws Exception {
        return r.getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    @Test
    void noResponseEverCarriesAPasswordHash() throws Exception {
        long viewer = viewer(100);
        long admin = admin();
        long company = company();
        String hashMarker = "$2a$"; // bcrypt

        for (var call : new String[][] {
                {"/viewer/me", bearer(viewer)}, {"/admin/users", bearer(admin)},
                {"/admin/users/" + viewer, bearer(admin)}, {"/company/campaigns", bearer(company)},
                {"/admin/stats", bearer(admin)}}) {
            MvcResult r = mvc.perform(get(call[0]).header("Authorization", call[1])).andReturn();
            assertThat(body(r)).as(call[0]).doesNotContain(hashMarker).doesNotContain("passwordHash")
                    .doesNotContain("password_hash");
        }
        MvcResult login = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"phoneNumber\":\"" + phoneOf(viewer) + "\",\"password\":\"" + PASSWORD + "\"}")).andReturn();
        assertThat(login.getResponse().getStatus()).isEqualTo(200);
        assertThat(body(login)).doesNotContain(hashMarker).doesNotContain("passwordHash");
    }

    @Test
    void errorsDoNotLeakStackTracesOrInternals() throws Exception {
        long admin = admin();

        for (String path : new String[] {"/admin/users/999999999", "/nope", "/admin/campaigns/abc"}) {
            MvcResult r = mvc.perform(get(path).header("Authorization", bearer(admin))).andReturn();
            String text = body(r);
            assertThat(text).as(path).doesNotContain("Exception").doesNotContain("at mn.uziy")
                    .doesNotContain("org.springframework").doesNotContain("trace").doesNotContain("hibernate")
                    .doesNotContain("SQL");
        }
    }

    @Test
    void theLoginAnswerIsTheSameForAnUnknownPhoneAndAWrongPassword() throws Exception {
        long viewer = viewer(0);
        var unknown = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"phoneNumber\":\"" + freshPhone() + "\",\"password\":\"whatever1\"}")).andReturn();
        var wrong = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"phoneNumber\":\"" + phoneOf(viewer) + "\",\"password\":\"whatever1\"}")).andReturn();

        assertThat(unknown.getResponse().getStatus()).isEqualTo(401).isEqualTo(wrong.getResponse().getStatus());
        assertThat(body(unknown)).isEqualTo(body(wrong).replace(phoneOf(viewer), ""));
    }

    // ------- headers, CORS, actuator ----------------------------------------

    @Test
    void securityHeadersAreSet() throws Exception {
        var r = mvc.perform(get("/platform-settings")).andReturn().getResponse();

        assertThat(r.getHeader("X-Content-Type-Options")).isEqualTo("nosniff");
        assertThat(r.getHeader("X-Frame-Options")).isNotNull();
    }

    @Test
    void anAuthenticatedResponseIsNotCacheable() throws Exception {
        long viewer = viewer(0);

        var r = mvc.perform(get("/viewer/me").header("Authorization", bearer(viewer))).andReturn().getResponse();

        assertThat(r.getHeader("Cache-Control")).contains("no-store");
    }

    @Test
    void aForeignOriginGetsNoCorsPermission() throws Exception {
        var r = mvc.perform(options("/viewer/me").header("Origin", "https://evil.example")
                .header("Access-Control-Request-Method", "GET")).andReturn().getResponse();

        assertThat(r.getHeader("Access-Control-Allow-Origin")).isNull();
    }

    @Test
    void theConfiguredPanelOriginsAreAllowed() throws Exception {
        var r = mvc.perform(options("/viewer/me").header("Origin", "http://localhost:3000")
                .header("Access-Control-Request-Method", "GET")).andReturn().getResponse();

        assertThat(r.getHeader("Access-Control-Allow-Origin")).isEqualTo("http://localhost:3000");
    }

    @ParameterizedTest
    @ValueSource(strings = {"/actuator/env", "/actuator/beans", "/actuator/mappings", "/actuator/heapdump",
            "/actuator/configprops", "/actuator/loggers", "/actuator/metrics", "/h2-console", "/swagger-ui.html",
            "/v3/api-docs"})
    void internalEndpointsAreNotExposed(String path) throws Exception {
        assertThat(statusWith(path, null)).as(path).isIn(401, 403, 404);
    }

    @Test
    void theHealthEndpointDoesNotLeakDetails() throws Exception {
        var r = mvc.perform(get("/actuator/health")).andReturn().getResponse();

        assertThat(r.getContentAsString()).doesNotContain("jdbc").doesNotContain("postgres")
                .doesNotContain("password").doesNotContain("diskSpace");
    }

    @Test
    void unsupportedMethodsAreRefusedCleanly() throws Exception {
        var r = mvc.perform(patch("/auth/login").contentType(MediaType.APPLICATION_JSON).content("{}")).andReturn()
                .getResponse();

        assertThat(r.getStatus()).isBetween(400, 499);
    }
}
