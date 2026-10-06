package mn.uziy.backend.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class DeviceRegistrationServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-06T10:00:00Z");

    private final DeviceTokenRepository tokens = mock(DeviceTokenRepository.class);
    private final DeviceRegistrationServiceImpl service =
            new DeviceRegistrationServiceImpl(tokens, Clock.fixed(NOW, ZoneOffset.UTC));

    private DeviceTokenEntity saved() {
        ArgumentCaptor<DeviceTokenEntity> captor = ArgumentCaptor.forClass(DeviceTokenEntity.class);
        verify(tokens).save(captor.capture());
        return captor.getValue();
    }

    @Test
    void newTokenIsInsertedForTheUserWithClockTimestamps() {
        when(tokens.findByToken("t1")).thenReturn(Optional.empty());

        service.register(42L, "t1", DevicePlatform.IOS);

        DeviceTokenEntity e = saved();
        assertThat(e.getToken()).isEqualTo("t1");
        assertThat(e.getUserId()).isEqualTo(42L);
        assertThat(e.getPlatform()).isEqualTo(DevicePlatform.IOS);
        assertThat(e.getCreatedAt()).isEqualTo(OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC));
        assertThat(e.getUpdatedAt()).isEqualTo(e.getCreatedAt());
    }

    private static DeviceTokenEntity existing(long userId, DevicePlatform platform) {
        DeviceTokenEntity e = new DeviceTokenEntity();
        e.setId(9L);
        e.setToken("t1");
        e.setUserId(userId);
        e.setPlatform(platform);
        e.setCreatedAt(OffsetDateTime.parse("2026-01-01T00:00:00Z"));
        e.setUpdatedAt(OffsetDateTime.parse("2026-01-01T00:00:00Z"));
        return e;
    }

    @Test
    void existingTokenOfTheSameUserOnlyRefreshesUpdatedAtAndPlatform() {
        when(tokens.findByToken("t1")).thenReturn(Optional.of(existing(42L, DevicePlatform.ANDROID)));

        service.register(42L, "t1", DevicePlatform.IOS);

        DeviceTokenEntity e = saved();
        assertThat(e.getId()).isEqualTo(9L);
        assertThat(e.getUserId()).isEqualTo(42L);
        assertThat(e.getPlatform()).isEqualTo(DevicePlatform.IOS);
        assertThat(e.getCreatedAt()).isEqualTo(OffsetDateTime.parse("2026-01-01T00:00:00Z"));
        assertThat(e.getUpdatedAt()).isEqualTo(OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC));
    }

    @Test
    void tokenHeldByAnotherUserIsReassignedToTheCaller() {
        when(tokens.findByToken("t1")).thenReturn(Optional.of(existing(7L, DevicePlatform.ANDROID)));

        service.register(42L, "t1", DevicePlatform.ANDROID);

        DeviceTokenEntity e = saved();
        assertThat(e.getId()).isEqualTo(9L);
        assertThat(e.getUserId()).isEqualTo(42L);
    }

    @Test
    void unregisterDeletesOnlyTheCallersToken() {
        service.unregister(42L, "t1");

        verify(tokens).deleteByUserIdAndToken(42L, "t1");
        verify(tokens, org.mockito.Mockito.never()).save(any());
    }
}
