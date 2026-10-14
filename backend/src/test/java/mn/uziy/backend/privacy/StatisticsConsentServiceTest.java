package mn.uziy.backend.privacy;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.privacy.StatisticsConsentRepository.Stored;
import org.junit.jupiter.api.Test;

class StatisticsConsentServiceTest {

    private static final long VIEWER = 100L;
    private static final Instant NOW = Instant.parse("2026-10-14T04:00:00Z");
    private static final String VERSION = StatisticsConsentService.CURRENT_VERSION;

    private final StatisticsConsentRepository consents = mock(StatisticsConsentRepository.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final StatisticsConsentServiceImpl service =
            new StatisticsConsentServiceImpl(consents, events, Clock.fixed(NOW, ZoneOffset.UTC));

    @Test
    void neverAskedIsUnaskedAndThatMeansNo() {
        when(consents.findForViewer(VIEWER)).thenReturn(Optional.of(new Stored(null, null, null)));

        assertThat(service.current(VIEWER).status()).isEqualTo(StatisticsConsentStatus.UNASKED);
    }

    @Test
    void aYesToAnOlderWordingMustBeAskedAgain() {
        when(consents.findForViewer(VIEWER)).thenReturn(Optional.of(
                new Stored("GRANTED", OffsetDateTime.parse("2025-01-01T00:00:00Z"), "2025-01-01")));

        assertThat(service.current(VIEWER).status()).isEqualTo(StatisticsConsentStatus.UNASKED);
    }

    @Test
    void aYesToTheCurrentWordingIsGranted() {
        OffsetDateTime at = OffsetDateTime.parse("2026-10-14T03:00:00Z");
        when(consents.findForViewer(VIEWER)).thenReturn(Optional.of(new Stored("GRANTED", at, VERSION)));

        StatisticsConsentDto dto = service.current(VIEWER);

        assertThat(dto.status()).isEqualTo(StatisticsConsentStatus.GRANTED);
        assertThat(dto.decidedAt()).isEqualTo(at);
    }

    @Test
    void decidingStoresTheChoiceWithTimeAndWordingAndIsAudited() {
        when(consents.findForViewer(VIEWER)).thenReturn(Optional.of(new Stored(null, null, null)));

        StatisticsConsentDto dto = service.decide(VIEWER, false);

        OffsetDateTime now = OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC);
        verify(consents).save(VIEWER, StatisticsConsentStatus.DECLINED, now, VERSION);
        verify(events).publish(new StatisticsConsentChanged(VIEWER, StatisticsConsentStatus.DECLINED, VERSION));
        assertThat(dto.status()).isEqualTo(StatisticsConsentStatus.DECLINED);
    }

    @Test
    void anUnknownViewerIs404() {
        when(consents.findForViewer(VIEWER)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.decide(VIEWER, true)).isInstanceOf(NotFoundException.class);
    }
}
