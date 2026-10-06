package mn.uziy.backend.security;

import mn.uziy.backend.domain.Role;

/** Authenticated caller extracted from a validated JWT. */
public record JwtPrincipal(long userId, Role role) {
}
