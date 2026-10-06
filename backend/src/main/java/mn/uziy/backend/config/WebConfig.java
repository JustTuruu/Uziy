package mn.uziy.backend.config;

import java.util.List;
import mn.uziy.backend.security.AuthArgumentResolver;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Registers the {@code @Auth} controller-parameter resolver. */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final AuthArgumentResolver authResolver;

    public WebConfig(AuthArgumentResolver authResolver) {
        this.authResolver = authResolver;
    }

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(authResolver);
    }
}
