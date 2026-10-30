package mn.uziy.backend.api;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import java.util.List;
import mn.uziy.backend.security.JwtPrincipal;
import org.springdoc.core.utils.SpringDocUtils;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * The API description served at {@code /v3/api-docs} (not in production). Its committed copy,
 * {@code docs/api/openapi.json}, is what the panel's TypeScript types are generated from and what the Flutter
 * models are checked against, so the three sides cannot drift apart silently.
 */
@Configuration
public class OpenApiConfig {

    static final String BEARER = "bearer";
    /** A fixed server, so the committed file does not change with the port a test happened to run on. */
    static final String LOCAL_SERVER = "http://localhost:8080";

    static {
        // Filled from the bearer token by AuthArgumentResolver, never sent by a client.
        SpringDocUtils.getConfig().addRequestWrapperToIgnore(JwtPrincipal.class);
    }

    @Bean
    public OpenAPI uziyOpenApi() {
        return new OpenAPI()
                .info(new Info().title("Uziy API").version("1"))
                .servers(List.of(new Server().url(LOCAL_SERVER)))
                .components(new Components().addSecuritySchemes(BEARER,
                        new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER));
    }

    @Bean
    public RequiredResponseFields requiredResponseFields() {
        return new RequiredResponseFields();
    }
}
