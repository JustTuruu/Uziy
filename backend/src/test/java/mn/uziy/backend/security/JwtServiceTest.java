package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import io.jsonwebtoken.security.SignatureException;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class JwtServiceTest {

    private static JwtService svc(String secret) {
        return new JwtService(new AppProperties(
                new AppProperties.Jwt(secret, 1), new AppProperties.Cors(java.util.List.of()), new AppProperties.Payments(false)));
    }

    private static JwtService svc() {
        return svc("a".repeat(64));
    }

    private static UserEntity user(long id, Role role) {
        UserEntity u = new UserEntity();
        u.setId(id);
        u.setPhoneNumber("1");
        u.setPasswordHash("x");
        u.setRole(role);
        return u;
    }

    @Test
    void issueThenParseRoundTripsIdAndRole() {
        JwtService svc = svc();
        String token = svc.issue(user(42, Role.VIEWER));
        JwtPrincipal p = svc.parse(token);
        assertThat(p.userId()).isEqualTo(42);
        assertThat(p.role()).isEqualTo(Role.VIEWER);
    }

    @Test
    void parseFailsOnATokenSignedWithADifferentSecret() {
        String token = svc("a".repeat(64)).issue(user(1, Role.ADMIN));
        JwtService tamperedVerifier = svc("b".repeat(64));
        assertThatThrownBy(() -> tamperedVerifier.parse(token)).isInstanceOf(SignatureException.class);
    }

    @Test
    void parseExtractsAdminRole() {
        JwtService svc = svc();
        assertThat(svc.parse(svc.issue(user(7, Role.ADMIN))).role()).isEqualTo(Role.ADMIN);
    }

    @Test
    void parseExtractsCompanyRole() {
        JwtService svc = svc();
        assertThat(svc.parse(svc.issue(user(9, Role.COMPANY))).role()).isEqualTo(Role.COMPANY);
    }
}
