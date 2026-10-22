package mn.uziy.backend.trusteddevice;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;

/** The rules decided in Java; the ones decided in SQL are in {@link TrustedDeviceServiceIntegrationTest}. */
class TrustedDeviceServiceTest {

    private static final long USER = 7L;
    private static final String SECRET = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCd";
    private static final Instant T0 = Instant.parse("2026-10-22T04:00:00Z");
    private static final OffsetDateTime NOW = OffsetDateTime.ofInstant(T0, ZoneOffset.UTC);

    private final TrustedDeviceRepository devices = mock(TrustedDeviceRepository.class);
    private final DeviceSecrets secrets = mock(DeviceSecrets.class);
    private final TrustedDeviceServiceImpl service =
            new TrustedDeviceServiceImpl(devices, secrets, Clock.fixed(T0, ZoneOffset.UTC));

    @Test
    void theTrustPeriodIsThirtyDaysAndTenBrowsersAreKept() {
        assertThat(TrustedDeviceServiceImpl.TRUST_PERIOD).isEqualTo(Duration.ofDays(30));
        assertThat(TrustedDeviceServiceImpl.MAX_DEVICES_PER_USER).isEqualTo(10);
    }

    @Test
    void trustStoresOnlyTheHashWithTheBrowserFamilyAndThirtyDaysOfTrust() {
        when(secrets.next()).thenReturn(SECRET);

        IssuedDevice issued = service.trust(USER, "Mozilla/5.0 Gecko/20100101 Firefox/140.0");

        ArgumentCaptor<TrustedDeviceEntity> row = ArgumentCaptor.forClass(TrustedDeviceEntity.class);
        verify(devices).save(row.capture());
        assertThat(row.getValue().getUserId()).isEqualTo(USER);
        assertThat(row.getValue().getTokenHash()).isEqualTo(DeviceSecrets.hash(SECRET)).doesNotContain(SECRET);
        assertThat(row.getValue().getLabel()).isEqualTo("Firefox");
        assertThat(row.getValue().getCreatedAt()).isEqualTo(NOW);
        assertThat(row.getValue().getLastUsedAt()).isEqualTo(NOW);
        assertThat(row.getValue().getExpiresAt()).isEqualTo(NOW.plusDays(30));
        assertThat(issued).isEqualTo(new IssuedDevice(SECRET, NOW.plusDays(30)));
    }

    @Test
    void trustThenForgetsAllButTheTenUsedMostRecently() {
        when(secrets.next()).thenReturn(SECRET);

        service.trust(USER, null);

        var order = inOrder(devices);
        order.verify(devices).save(any());
        order.verify(devices).evictBeyond(USER, TrustedDeviceServiceImpl.MAX_DEVICES_PER_USER, NOW);
    }

    @Test
    void aBrowserWithoutAKnownFamilyHasNoLabel() {
        when(secrets.next()).thenReturn(SECRET);

        service.trust(USER, "curl/8.7.1");

        ArgumentCaptor<TrustedDeviceEntity> row = ArgumentCaptor.forClass(TrustedDeviceEntity.class);
        verify(devices).save(row.capture());
        assertThat(row.getValue().getLabel()).isNull();
    }

    @Test
    void theIssuedSecretIsNeverPrinted() {
        assertThat(new IssuedDevice(SECRET, NOW).toString()).doesNotContain(SECRET);
    }

    @Test
    void aKnownBrowserIsLookedUpByItsHashForThatUserAndTouched() {
        when(devices.touchIfTrusted(DeviceSecrets.hash(SECRET), USER, NOW)).thenReturn(1);

        assertThat(service.recognises(USER, SECRET)).isTrue();
    }

    @Test
    void aSecretTheDatabaseDoesNotTrustIsAStranger() {
        when(devices.touchIfTrusted(any(), anyLong(), any())).thenReturn(0);

        assertThat(service.recognises(USER, SECRET)).isFalse();
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"not a token", "'; DROP TABLE users; --", "ééééé"})
    void aMissingOrMalformedSecretIsAStrangerWithoutAskingTheDatabase(String secret) {
        assertThat(service.recognises(USER, secret)).isFalse();
        verifyNoInteractions(devices);
    }

    @Test
    void anOverlongSecretIsNotEvenHashed() {
        assertThat(service.recognises(USER, "a".repeat(DeviceSecrets.MAX_SECRET_LENGTH + 1))).isFalse();
        verifyNoInteractions(devices);
    }

    @Test
    void revokeAllDeletesEveryBrowserOfTheUser() {
        when(devices.deleteAllOfUser(USER)).thenReturn(3);

        assertThat(service.revokeAll(USER)).isEqualTo(3);
    }
}
