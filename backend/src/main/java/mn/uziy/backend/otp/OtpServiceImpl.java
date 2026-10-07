package mn.uziy.backend.otp;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.Optional;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.DomainException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.UnavailableException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OtpServiceImpl implements OtpService {

    private static final Logger LOG = LoggerFactory.getLogger(OtpServiceImpl.class);

    public static final Duration TTL = Duration.ofMinutes(5);
    public static final Duration COOLDOWN = Duration.ofSeconds(60);
    public static final Duration HOURLY_WINDOW = Duration.ofHours(1);
    public static final int MAX_PER_HOUR = 5;
    public static final int MAX_ATTEMPTS = 5;

    private final OtpCodeRepository codes;
    private final OtpCodeGenerator generator;
    private final OtpSender sender;
    private final PasswordEncoder encoder;
    private final Clock clock;

    public OtpServiceImpl(OtpCodeRepository codes, OtpCodeGenerator generator, OtpSender sender,
                          PasswordEncoder encoder, Clock clock) {
        this.codes = codes;
        this.generator = generator;
        this.sender = sender;
        this.encoder = encoder;
        this.clock = clock;
    }

    @Override
    @Transactional
    public void issue(String phoneNumber, OtpPurpose purpose) {
        OffsetDateTime now = OffsetDateTime.now(clock);
        requireNotTooSoon(phoneNumber, purpose, now);
        if (codes.countByPhoneNumberAndPurposeAndCreatedAtAfter(
                phoneNumber, purpose, now.minus(HOURLY_WINDOW)) >= MAX_PER_HOUR) {
            throw new TooManyRequestsException(TOO_MANY);
        }

        String code = generator.next();
        OtpCodeEntity row = new OtpCodeEntity();
        row.setPhoneNumber(phoneNumber);
        row.setPurpose(purpose);
        row.setCodeHash(encoder.encode(code));
        row.setCreatedAt(now);
        row.setExpiresAt(now.plus(TTL));
        codes.save(row);

        try {
            sender.send(phoneNumber, code, purpose);
        } catch (RuntimeException e) {
            // Rolls the row back too: a code nobody received must not eat the hourly allowance.
            LOG.warn("otp send failed for purpose={}: {}", purpose, e.toString());
            throw new UnavailableException(SEND_FAILED);
        }
    }

    private void requireNotTooSoon(String phoneNumber, OtpPurpose purpose, OffsetDateTime now) {
        Optional<OtpCodeEntity> latest =
                codes.findFirstByPhoneNumberAndPurposeOrderByCreatedAtDesc(phoneNumber, purpose);
        if (latest.isPresent() && latest.get().getCreatedAt().plus(COOLDOWN).isAfter(now)) {
            throw new TooManyRequestsException(TOO_SOON);
        }
    }

    /**
     * {@code noRollbackFor}: a wrong guess throws, but its attempt count must still be saved —
     * otherwise the limit would never trigger and codes could be brute-forced.
     */
    @Override
    @Transactional(noRollbackFor = DomainException.class)
    public void verifyAndConsume(String phoneNumber, OtpPurpose purpose, String code) {
        OtpCodeEntity row = codes.findFirstByPhoneNumberAndPurposeOrderByCreatedAtDesc(phoneNumber, purpose)
                .orElseThrow(() -> new BadRequestException(INVALID_CODE));
        OffsetDateTime now = OffsetDateTime.now(clock);
        if (row.isConsumed() || !row.getExpiresAt().isAfter(now) || row.getAttempts() >= MAX_ATTEMPTS) {
            throw new BadRequestException(INVALID_CODE);
        }
        if (!encoder.matches(code, row.getCodeHash())) {
            row.setAttempts(row.getAttempts() + 1);
            codes.save(row);
            throw new BadRequestException(INVALID_CODE);
        }
        row.setConsumed(true);
        codes.save(row);
    }
}
