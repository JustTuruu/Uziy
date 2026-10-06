package mn.uziy.backend.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Typed {@code uziy.*} configuration. Registered via
 * {@code @EnableConfigurationProperties(AppProperties.class)} on SecurityConfig.
 */
@ConfigurationProperties(prefix = "uziy")
public record AppProperties(
        @DefaultValue Jwt jwt,
        @DefaultValue Cors cors,
        @DefaultValue Payments payments) {

    /** JWT signing secret and token lifetime. */
    public record Jwt(@DefaultValue("") String secret, @DefaultValue("24") long ttlHours) {
        public Jwt {
            if (secret == null) {
                secret = "";
            }
        }
    }

    /** Allowed CORS origins. */
    public record Cors(List<String> allowedOrigins) {
        public Cors {
            allowedOrigins = allowedOrigins == null ? List.of() : List.copyOf(allowedOrigins);
        }
    }

    /**
     * {@code simulated = true} → POST /company/campaigns/{id}/pay marks the
     * campaign paid instantly (test "Төлөх" button). {@code false} → the endpoint
     * answers 503 until a real gateway (QPay) is wired. Defaults to false in
     * code so a missing property can never hand out free campaigns;
     * application.yml turns it on for dev via PAYMENTS_SIMULATED.
     */
    public record Payments(@DefaultValue("false") boolean simulated) {
    }
}
