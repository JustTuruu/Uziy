package mn.uziy.backend.config;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * Refuses to start in the {@code prod} profile while any development convenience is still switched on.
 * Each one is harmless on a laptop and a hole in production: a known JWT secret lets anyone mint an admin
 * token, the seeded accounts have known passwords, simulated payments hand out free campaigns, and a logging
 * one-time-code sender means no real user ever receives a code, and simulated phone verification lets anyone
 * register any number. Better a server that will not boot than one that
 * boots open.
 */
@Component
@Profile("prod")
public class ProductionReadinessCheck implements ApplicationRunner {

    /** The secret in application.yml's default; also what a copied dev config would carry. */
    static final String DEV_JWT_SECRET_PREFIX = "dev-only-secret";
    static final int MIN_JWT_SECRET_BYTES = 32;

    /** Phone numbers of the accounts the V2 dev seed creates (admin, companies, viewers). */
    static final List<String> SEEDED_PHONES =
            List.of("99990000", "88112233", "99114455", "88778899", "99551122", "88221199");

    private final AppProperties props;
    private final UserRepository users;
    private final String otpSender;
    private final String phoneVerificationProvider;

    public ProductionReadinessCheck(AppProperties props, UserRepository users,
                                    @Value("${uziy.otp.sender:logging}") String otpSender,
                                    @Value("${uziy.phone-verification.provider:simulated}")
                                    String phoneVerificationProvider) {
        this.props = props;
        this.users = users;
        this.otpSender = otpSender;
        this.phoneVerificationProvider = phoneVerificationProvider;
    }

    @Override
    public void run(ApplicationArguments args) {
        List<String> problems = problems();
        if (!problems.isEmpty()) {
            throw new IllegalStateException("Not safe to run in production:\n - " + String.join("\n - ", problems));
        }
    }

    /** Everything wrong with the current configuration and data; empty when production-ready. */
    List<String> problems() {
        List<String> problems = new ArrayList<>();
        String secret = props.jwt().secret();
        if (secret.startsWith(DEV_JWT_SECRET_PREFIX)) {
            problems.add("JWT_SECRET is the development default: set a secret of your own");
        } else if (secret.getBytes(StandardCharsets.UTF_8).length < MIN_JWT_SECRET_BYTES) {
            problems.add("JWT_SECRET is shorter than " + MIN_JWT_SECRET_BYTES + " bytes");
        }
        if (props.payments().simulated()) {
            problems.add("PAYMENTS_SIMULATED=true: campaigns would be \"paid\" without any money");
        }
        if ("logging".equals(otpSender)) {
            problems.add("OTP_SENDER=logging: one-time codes are only logged, nobody would receive one");
        }
        if ("simulated".equals(phoneVerificationProvider)) {
            problems.add("PHONE_VERIFICATION_PROVIDER=simulated: every phone would count as verified without an SMS");
        }
        for (String origin : props.cors().allowedOrigins()) {
            if (origin.contains("localhost") || origin.contains("127.0.0.1")) {
                problems.add("CORS allows a local origin (" + origin + "): set CORS_ALLOWED_ORIGINS to the real panels");
            }
        }
        for (String phone : SEEDED_PHONES) {
            if (users.existsByPhoneNumber(phone)) {
                problems.add("the dev-seed account " + phone + " exists (known password): delete the seed data");
            }
        }
        return problems;
    }
}
