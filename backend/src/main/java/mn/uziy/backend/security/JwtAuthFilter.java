package mn.uziy.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import mn.uziy.backend.domain.AccountState;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtService jwt;
    private final UserRepository users;

    public JwtAuthFilter(JwtService jwt, UserRepository users) {
        this.jwt = jwt;
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith(BEARER_PREFIX)) {
            try {
                JwtService.ParsedToken token = jwt.parseToken(header.substring(BEARER_PREFIX.length()).trim());
                JwtPrincipal principal = token.principal();
                // The token only proves who the user WAS when it was issued. The account may have been
                // deleted, its role changed or its password reset since, and that must take effect now,
                // not when the token expires.
                if (!users.accountState(principal.userId())
                        .filter(state -> stillValid(state, principal, token.issuedAt()))
                        .isPresent()) {
                    filterChain.doFilter(request, response);
                    return;
                }
                var auth = new UsernamePasswordAuthenticationToken(
                        principal,
                        null,
                        List.of(new SimpleGrantedAuthority("ROLE_" + principal.role().name())));
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (Exception ignored) {
                // Invalid token → leave context anonymous; downstream will 401/403.
            }
        }
        filterChain.doFilter(request, response);
    }

    /**
     * Same role as in the token, and the token not older than the last password change. JWT keeps whole seconds,
     * so the change time is cut to seconds too: a token issued in the same second as the reset (the new login)
     * stays valid.
     */
    static boolean stillValid(AccountState state, JwtPrincipal principal, Instant issuedAt) {
        if (state.role() != principal.role()) {
            return false;
        }
        OffsetDateTime changed = state.credentialsChangedAt();
        return changed == null || !issuedAt.isBefore(changed.toInstant().truncatedTo(ChronoUnit.SECONDS));
    }
}
