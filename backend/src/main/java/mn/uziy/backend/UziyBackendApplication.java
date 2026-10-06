package mn.uziy.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Application entry point.
 *
 * <p>Authentication is stateless JWT only ({@code JwtAuthFilter}), so Spring Security's
 * default in-memory user (and its "Using generated security password" log line) is excluded.
 */
@SpringBootApplication(excludeName =
        "org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration")
public class UziyBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(UziyBackendApplication.class, args);
    }
}
