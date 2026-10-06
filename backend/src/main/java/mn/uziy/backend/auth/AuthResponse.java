package mn.uziy.backend.auth;

public record AuthResponse(String token, Me user) {
}
