package mn.uziy.backend.phoneverify;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.UUID;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.UnavailableException;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.otp.OtpCodeGenerator;
import mn.uziy.backend.otp.OtpService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Every SMS the user sends to the short code costs them money (150 ₮ at verify.mn), so new checks are
 * rate-limited and a confirmed check is never asked about again.
 */
@Service
public class PhoneVerificationServiceImpl implements PhoneVerificationService, VerifiedPhoneClaim {

    private static final Logger LOG = LoggerFactory.getLogger(PhoneVerificationServiceImpl.class);

    public static final Duration COOLDOWN = Duration.ofSeconds(60);
    public static final Duration HOURLY_WINDOW = Duration.ofHours(1);
    public static final int MAX_PER_HOUR = 5;
    /** How long after the SMS a confirmed check can still finish a registration. */
    public static final Duration CLAIM_WINDOW = Duration.ofMinutes(30);

    private final PhoneVerificationRepository verifications;
    private final PhoneVerificationGateway gateway;
    private final OtpCodeGenerator codes;
    private final UserRepository users;
    private final PhoneVerificationMapper mapper;
    private final Clock clock;

    public PhoneVerificationServiceImpl(PhoneVerificationRepository verifications, PhoneVerificationGateway gateway,
                                        OtpCodeGenerator codes, UserRepository users,
                                        PhoneVerificationMapper mapper, Clock clock) {
        this.verifications = verifications;
        this.gateway = gateway;
        this.codes = codes;
        this.users = users;
        this.mapper = mapper;
        this.clock = clock;
    }

    @Override
    @Transactional
    public PhoneVerificationStartedRes start(String phoneNumber) {
        if (users.existsByPhoneNumber(phoneNumber)) {
            throw new ConflictException(PHONE_TAKEN);
        }
        OffsetDateTime now = OffsetDateTime.now(clock);
        requireWithinLimits(phoneNumber, now);

        PhoneVerificationSession session;
        try {
            session = gateway.start(phoneNumber, codes.next());
        } catch (PhoneVerificationGatewayException e) {
            LOG.warn("phone verification start failed: {}", e.getMessage());
            throw new UnavailableException(START_FAILED);
        }

        PhoneVerificationEntity row = new PhoneVerificationEntity();
        row.setId(UUID.randomUUID());
        row.setPhoneNumber(phoneNumber);
        row.setProviderSessionId(session.sessionId());
        row.setStatus(PhoneVerificationStatus.PENDING);
        row.setExpiresAt(session.expiresAt());
        row.setCreatedAt(now);
        return mapper.toStarted(verifications.save(row), session);
    }

    private void requireWithinLimits(String phoneNumber, OffsetDateTime now) {
        boolean tooSoon = verifications.findFirstByPhoneNumberOrderByCreatedAtDesc(phoneNumber)
                .filter(latest -> latest.getCreatedAt().plus(COOLDOWN).isAfter(now))
                .isPresent();
        if (tooSoon) {
            throw new TooManyRequestsException(OtpService.TOO_SOON);
        }
        if (verifications.countByPhoneNumberAndCreatedAtAfter(phoneNumber, now.minus(HOURLY_WINDOW)) >= MAX_PER_HOUR) {
            throw new TooManyRequestsException(OtpService.TOO_MANY);
        }
    }

    @Override
    @Transactional
    public PhoneVerificationStateRes check(UUID verificationId) {
        PhoneVerificationEntity row = verifications.findById(verificationId)
                .orElseThrow(() -> new NotFoundException(NOT_FOUND));
        refresh(row);
        return mapper.toState(row);
    }

    @Override
    @Transactional
    public void claim(UUID verificationId, String phoneNumber) {
        PhoneVerificationEntity row = verifications.findById(verificationId)
                .filter(r -> r.getPhoneNumber().equals(phoneNumber))
                .orElseThrow(() -> new BadRequestException(NOT_VERIFIED));
        // The app may register before its next poll saw the SMS: ask once more.
        refresh(row);
        OffsetDateTime verifiedAfter = OffsetDateTime.now(clock).minus(CLAIM_WINDOW);
        if (verifications.tryClaim(verificationId, phoneNumber, verifiedAfter) == 0) {
            throw new BadRequestException(NOT_VERIFIED);
        }
    }

    /**
     * Brings a pending row up to date: expired by our clock, or whatever the provider now says. A provider
     * outage leaves it pending — the app simply polls again.
     */
    private void refresh(PhoneVerificationEntity row) {
        if (row.getStatus() != PhoneVerificationStatus.PENDING) {
            return;
        }
        OffsetDateTime now = OffsetDateTime.now(clock);
        PhoneVerificationStatus next;
        if (!row.getExpiresAt().isAfter(now)) {
            next = PhoneVerificationStatus.EXPIRED;
        } else {
            try {
                next = gateway.status(row.getProviderSessionId());
            } catch (PhoneVerificationGatewayException e) {
                LOG.warn("phone verification status failed: {}", e.getMessage());
                return;
            }
        }
        if (next == PhoneVerificationStatus.PENDING) {
            return;
        }
        row.setStatus(next);
        if (next == PhoneVerificationStatus.VERIFIED) {
            row.setVerifiedAt(now);
        }
        verifications.save(row);
    }
}
