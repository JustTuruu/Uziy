package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.DynamicTest;
import org.junit.jupiter.api.TestFactory;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * Every protected endpoint, called as every kind of caller: nobody, each role, and each wrong role.
 * Only the right role may get past the door (any answer except 401/403 — a 400 or 404 for a made-up id is fine);
 * everyone else must be turned away.
 */
class AccessControlMatrixIntegrationTest extends AbstractApiIntegrationTest {

    private record Endpoint(HttpMethod method, String path, String role, String body) {
        @Override
        public String toString() {
            return method + " " + path + " [" + role + "]";
        }
    }

    private static Endpoint ep(HttpMethod m, String path, String role) {
        return new Endpoint(m, path, role, "{}");
    }

    /** Every non-public route of the API, with the one role allowed to call it. */
    private static List<Endpoint> protectedEndpoints() {
        return protectedEndpoints(1, 1);
    }

    /** The same routes using a campaign the COMPANY caller owns and a payout request that exists. */
    private static List<Endpoint> protectedEndpoints(long campaign, long payout) {
        return List.of(
                ep(HttpMethod.GET, "/admin/stats", "ADMIN"),
                ep(HttpMethod.GET, "/admin/users", "ADMIN"),
                ep(HttpMethod.GET, "/admin/users/1", "ADMIN"),
                ep(HttpMethod.PATCH, "/admin/users/1/verify", "ADMIN"),
                ep(HttpMethod.POST, "/admin/users/1/trusted-devices/forget", "ADMIN"),
                ep(HttpMethod.GET, "/admin/companies", "ADMIN"),
                ep(HttpMethod.POST, "/admin/companies", "ADMIN"),
                ep(HttpMethod.GET, "/admin/admins", "ADMIN"),
                ep(HttpMethod.POST, "/admin/admins", "ADMIN"),
                ep(HttpMethod.GET, "/admin/campaigns", "ADMIN"),
                ep(HttpMethod.GET, "/admin/campaigns/1", "ADMIN"),
                ep(HttpMethod.PATCH, "/admin/campaigns/1/moderate?decision=ACTIVE", "ADMIN"),
                ep(HttpMethod.PATCH, "/admin/platform-settings", "ADMIN"),
                ep(HttpMethod.GET, "/admin/payouts", "ADMIN"),
                ep(HttpMethod.GET, "/admin/payouts/history", "ADMIN"),
                ep(HttpMethod.PATCH, "/admin/payouts/" + payout + "/decision?decision=APPROVED", "ADMIN"),
                ep(HttpMethod.GET, "/company/campaigns", "COMPANY"),
                ep(HttpMethod.GET, "/company/campaigns/" + campaign, "COMPANY"),
                ep(HttpMethod.POST, "/company/campaigns", "COMPANY"),
                ep(HttpMethod.POST, "/company/campaigns/" + campaign + "/pay", "COMPANY"),
                ep(HttpMethod.DELETE, "/company/campaigns/" + campaign + "/image", "COMPANY"),
                ep(HttpMethod.GET, "/viewer/consents/statistics", "VIEWER"),
                ep(HttpMethod.PUT, "/viewer/me/name", "VIEWER"),
                ep(HttpMethod.GET, "/admin/insights/overview", "ADMIN"),
                ep(HttpMethod.GET, "/admin/insights/questions", "ADMIN"),
                ep(HttpMethod.GET, "/admin/insights/access-log", "ADMIN"),
                ep(HttpMethod.GET, "/company/payments", "COMPANY"),
                ep(HttpMethod.PATCH, "/company/campaigns/" + campaign + "/status?status=PAUSED", "COMPANY"),
                ep(HttpMethod.GET, "/company/analytics", "COMPANY"),
                ep(HttpMethod.GET, "/viewer/me", "VIEWER"),
                ep(HttpMethod.DELETE, "/viewer/me", "VIEWER"),
                ep(HttpMethod.GET, "/viewer/feed", "VIEWER"),
                ep(HttpMethod.GET, "/viewer/history", "VIEWER"),
                ep(HttpMethod.GET, "/viewer/campaigns/1/questions", "VIEWER"),
                ep(HttpMethod.POST, "/viewer/campaigns/1/submit", "VIEWER"),
                ep(HttpMethod.POST, "/viewer/payouts", "VIEWER"),
                ep(HttpMethod.GET, "/viewer/payouts", "VIEWER"),
                ep(HttpMethod.POST, "/viewer/devices", "VIEWER"),
                ep(HttpMethod.DELETE, "/viewer/devices?token=abc", "VIEWER"));
    }

    private MockHttpServletRequestBuilder build(Endpoint e, String authorization) {
        MockHttpServletRequestBuilder b = request(e.method(), e.path());
        if (e.method() != HttpMethod.GET && e.method() != HttpMethod.DELETE) {
            b.contentType(MediaType.APPLICATION_JSON).content(e.body());
        }
        if (authorization != null) {
            b.header("Authorization", authorization);
        }
        return b;
    }

    private int statusOf(Endpoint e, String authorization) throws Exception {
        return mvc.perform(build(e, authorization)).andReturn().getResponse().getStatus();
    }

    private static boolean turnedAway(int status) {
        return status == 401 || status == 403;
    }

    @TestFactory
    Stream<DynamicTest> everyProtectedEndpointTurnsAnonymousCallersAway() {
        return protectedEndpoints().stream().map(e -> DynamicTest.dynamicTest(e.toString(), () ->
                assertThat(statusOf(e, null)).as("anonymous → %s", e).isIn(401, 403)));
    }

    @TestFactory
    Stream<DynamicTest> everyProtectedEndpointTurnsWrongRolesAway() {
        long viewer = viewer(0);
        long company = company();
        long admin = admin();
        List<DynamicTest> tests = new ArrayList<>();
        for (Endpoint e : protectedEndpoints()) {
            for (var caller : List.of(
                    java.util.Map.entry("VIEWER", viewer),
                    java.util.Map.entry("COMPANY", company),
                    java.util.Map.entry("ADMIN", admin))) {
                if (caller.getKey().equals(e.role())) {
                    continue;
                }
                tests.add(DynamicTest.dynamicTest(caller.getKey() + " → " + e, () ->
                        assertThat(statusOf(e, bearer(caller.getValue())))
                                .as("%s calling %s", caller.getKey(), e).isEqualTo(403)));
            }
        }
        return tests.stream();
    }

    @TestFactory
    Stream<DynamicTest> theRightRoleGetsPastTheDoor() {
        long viewer = viewer(0);
        long company = company();
        long admin = admin();
        long ownCampaign = activeCampaign(company);
        long payout = jdbc.queryForObject("""
                INSERT INTO payout_requests (user_id, amount, bank, account_number, account_name)
                VALUES (?, 500, 'Khan Bank', '1', 'A') RETURNING id""", Long.class, viewer);
        var tokens = java.util.Map.of("VIEWER", viewer, "COMPANY", company, "ADMIN", admin);
        return protectedEndpoints(ownCampaign, payout).stream().map(e -> DynamicTest.dynamicTest(e.toString(), () -> {
            int status = statusOf(e, bearer(tokens.get(e.role())));
            assertThat(turnedAway(status)).as("%s answered %d", e, status).isFalse();
            assertThat(status).as("%s must not crash", e).isLessThan(500);
        }));
    }

    @TestFactory
    Stream<DynamicTest> publicEndpointsNeedNoToken() {
        List<Endpoint> open = List.of(
                ep(HttpMethod.GET, "/platform-settings", "-"),
                ep(HttpMethod.GET, "/public/feed", "-"),
                ep(HttpMethod.GET, "/actuator/health", "-"),
                new Endpoint(HttpMethod.POST, "/auth/password/reset", "-", "{\"phoneNumber\":\"" + freshPhone()
                        + "\",\"verificationId\":\"" + java.util.UUID.randomUUID() + "\",\"newPassword\":\"secret12\"}"),
                new Endpoint(HttpMethod.POST, "/auth/phone-verifications", "-", "{\"phoneNumber\":\"" + freshPhone() + "\"}"),
                ep(HttpMethod.GET, "/auth/phone-verifications/" + java.util.UUID.randomUUID(), "-"),
                ep(HttpMethod.POST, "/auth/phone-verifications/simulated-sms/unknown", "-"),
                new Endpoint(HttpMethod.POST, "/auth/login/verify", "-", "{\"phoneNumber\":\"" + freshPhone()
                        + "\",\"verificationId\":\"" + java.util.UUID.randomUUID() + "\"}"));
        return open.stream().map(e -> DynamicTest.dynamicTest(e.toString(), () ->
                assertThat(turnedAway(statusOf(e, null))).as("%s", e).isFalse()));
    }

    @org.junit.jupiter.api.Test
    void loginAnswersAWrongPasswordWith401NotWith403() throws Exception {
        var login = new Endpoint(HttpMethod.POST, "/auth/login", "-",
                "{\"phoneNumber\":\"" + freshPhone() + "\",\"password\":\"x\"}");

        assertThat(statusOf(login, null)).isEqualTo(401);
    }
}
