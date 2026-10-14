package mn.uziy.backend.privacy;

import java.time.Clock;
import java.time.OffsetDateTime;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class StatisticsConsentServiceImpl implements StatisticsConsentService {

    private final StatisticsConsentRepository consents;
    private final DomainEventPublisher events;
    private final Clock clock;

    public StatisticsConsentServiceImpl(StatisticsConsentRepository consents, DomainEventPublisher events,
                                        Clock clock) {
        this.consents = consents;
        this.events = events;
        this.clock = clock;
    }

    @Override
    @Transactional(readOnly = true)
    public StatisticsConsentDto current(long viewerId) {
        StatisticsConsentRepository.Stored stored = consents.findForViewer(viewerId)
                .orElseThrow(() -> new NotFoundException(Messages.USER_NOT_FOUND));
        boolean answeredThisWording = stored.status() != null && CURRENT_VERSION.equals(stored.version());
        if (!answeredThisWording) {
            return new StatisticsConsentDto(StatisticsConsentStatus.UNASKED, null, CURRENT_VERSION);
        }
        return new StatisticsConsentDto(StatisticsConsentStatus.valueOf(stored.status()), stored.decidedAt(),
                CURRENT_VERSION);
    }

    @Override
    @Transactional
    public StatisticsConsentDto decide(long viewerId, boolean granted) {
        consents.findForViewer(viewerId).orElseThrow(() -> new NotFoundException(Messages.USER_NOT_FOUND));
        StatisticsConsentStatus status = granted ? StatisticsConsentStatus.GRANTED : StatisticsConsentStatus.DECLINED;
        OffsetDateTime now = OffsetDateTime.now(clock);
        consents.save(viewerId, status, now, CURRENT_VERSION);
        events.publish(new StatisticsConsentChanged(viewerId, status, CURRENT_VERSION));
        return new StatisticsConsentDto(status, now, CURRENT_VERSION);
    }
}
