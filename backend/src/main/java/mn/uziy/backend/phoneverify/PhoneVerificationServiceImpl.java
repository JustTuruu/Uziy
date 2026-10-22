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
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Every SMS the user sends to the short code costs them money (150 ₮ at verify.mn), so new checks are
 * rate-limited and a confirmed check is never asked about again.
 */
@Service
public class PhoneVerificationServiceImpl implements PhoneVerificationService, VerifiedPhoneClaim, LoginPhoneCheck {

    private static final Logger LOG = LoggerFactory.getLogger(PhoneVerificationServiceImpl.class);

    public static final Duration COOLDOWN = Duration.ofSeconds(60);
    public static final Duration HOURLY_WINDOW = Duration.ofHours(1);
    public static final int MAX_PER_HOUR = 5;
    /** How long after the SMS a confirmed check can still finish a registration or a reset. */
    public static final Duration CLAIM_WINDOW = PhoneVerificationPurpose.REGISTER.claimWindow();
    /** First key of the advisory lock that serialises check starts per phone ("PHON"), apart from any other lock. */
    static final int START_LOCK_NAMESPACE = 0x50484F4E;

    private final PhoneVerificationRepository verifications;
    private final PhoneVerificationGateway gateway;
    private final VerificationCodeGenerator codes;
    private final UserRepository users;
    private final PhoneVerificationMapper mapper;
    private final Clock clock;

    public PhoneVerificationServiceImpl(PhoneVerificationRepository verifications, PhoneVerificationGateway gateway,
                                        VerificationCodeGenerator codes, UserRepository users,
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
    public PhoneVerificationStartedRes start(String phoneNumber, PhoneVerificationPurpose purpose) {
        // The account first: a taken phone answers 409 even right after its own check (owner's decision), and a
        // purpose the endpoint does not offer never reaches the limits or the lock.
        requireAccountState(phoneNumber, purpose);
        return open(phoneNumber, purpose, lockAndRequireWithinLimits(phoneNumber));
    }

    /** The password was proved by the caller (the login), so no account check here — only the SMS limits. */
    @Override
    @Transactional
    public PhoneVerificationStartedRes openForLogin(String phoneNumber, PhoneVerificationPurpose purpose) {
        if (!purpose.isLoginStep()) {
            throw new IllegalArgumentException("not a login step: " + purpose);
        }
        return open(phoneNumber, purpose, lockAndRequireWithinLimits(phoneNumber));
    }

    private PhoneVerificationStartedRes open(String phoneNumber, PhoneVerificationPurpose purpose,
                                             OffsetDateTime now) {
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
        row.setPurpose(purpose);
        row.setProviderSessionId(session.sessionId());
        row.setStatus(PhoneVerificationStatus.PENDING);
        row.setExpiresAt(session.expiresAt());
        row.setCreatedAt(now);
        return mapper.toStarted(verifications.save(row), session);
    }

    /**
     * Checked before the user is asked to pay for an SMS: registering needs a free number, a reset needs a
     * viewer's number. (Registration already says when a number is taken, so saying "no account" here
     * reveals nothing new — and spares a stranger a paid SMS that could never lead anywhere.)
     */
    private void requireAccountState(String phoneNumber, PhoneVerificationPurpose purpose) {
        switch (purpose) {
            case REGISTER -> {
                if (users.existsByPhoneNumber(phoneNumber)) {
                    throw new ConflictException(PHONE_TAKEN);
                }
            }
            case PASSWORD_RESET -> {
                boolean viewer = users.findByPhoneNumber(phoneNumber)
                        .filter(u -> u.getRole() == Role.VIEWER)
                        .isPresent();
                if (!viewer) {
                    throw new NotFoundException(ACCOUNT_NOT_FOUND);
                }
            }
            // Only a correct password opens one (openForLogin); a stranger must not get a console phone texted.
            case ADMIN_LOGIN, COMPANY_LOGIN -> throw new BadRequestException(PURPOSE_NOT_OFFERED);
        }
    }

    /**
     * Read-then-insert is only safe one at a time: two parallel taps used to both pass the cool-down and send
     * the user two paid SMS codes. The advisory lock lasts until the caller's transaction has committed its new
     * row, so the next start for this phone sees it. Returns the time the limits were judged at.
     */
    private OffsetDateTime lockAndRequireWithinLimits(String phoneNumber) {
        verifications.lockPhone(START_LOCK_NAMESPACE, phoneNumber);
        OffsetDateTime now = OffsetDateTime.now(clock);
        requireWithinLimits(phoneNumber, now);
        return now;
    }

    private void requireWithinLimits(String phoneNumber, OffsetDateTime now) {
        boolean tooSoon = verifications.findFirstByPhoneNumberOrderByCreatedAtDesc(phoneNumber)
                .filter(latest -> latest.getCreatedAt().plus(COOLDOWN).isAfter(now))
                .isPresent();
        if (tooSoon) {
            throw new TooManyRequestsException(TOO_SOON);
        }
        if (verifications.countByPhoneNumberAndCreatedAtAfter(phoneNumber, now.minus(HOURLY_WINDOW)) >= MAX_PER_HOUR) {
            throw new TooManyRequestsException(TOO_MANY);
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
    public void claim(UUID verificationId, String phoneNumber, PhoneVerificationPurpose purpose) {
        PhoneVerificationEntity row = verifications.findById(verificationId)
                .filter(r -> r.getPhoneNumber().equals(phoneNumber) && r.getPurpose() == purpose)
                .orElseThrow(() -> new BadRequestException(NOT_VERIFIED));
        // The app may finish before its next poll saw the SMS: ask once more.
        refresh(row);
        OffsetDateTime verifiedAfter = OffsetDateTime.now(clock).minus(purpose.claimWindow());
        if (verifications.tryClaim(verificationId, phoneNumber, purpose, verifiedAfter) == 0) {
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
