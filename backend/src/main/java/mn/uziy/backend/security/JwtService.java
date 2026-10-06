package mn.uziy.backend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import javax.crypto.SecretKey;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private static final String ROLE_CLAIM = "role";
    private static final long MILLIS_PER_HOUR = 3600L * 1000L;

    private final AppProperties props;
    private volatile SecretKey key;

    public JwtService(AppProperties props) {
        this.props = props;
    }

    /** Lazily built, as in the Kotlin original (secret may be validated only on first use). */
    private SecretKey key() {
        SecretKey k = key;
        if (k == null) {
            k = Keys.hmacShaKeyFor(props.jwt().secret().getBytes(StandardCharsets.UTF_8));
            key = k;
        }
        return k;
    }

    public String issue(UserEntity user) {
        Date now = new Date();
        Date exp = new Date(now.getTime() + props.jwt().ttlHours() * MILLIS_PER_HOUR);
        return Jwts.builder()
                .subject(String.valueOf(user.getId()))
                .claim(ROLE_CLAIM, user.getRole().name())
                .issuedAt(now)
                .expiration(exp)
                .signWith(key())
                .compact();
    }

    public JwtPrincipal parse(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key())
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return new JwtPrincipal(
                Long.parseLong(claims.getSubject()),
                Role.valueOf(claims.get(ROLE_CLAIM, String.class)));
    }
}
