package mn.uziy.backend.settings;

import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import mn.uziy.backend.domain.PlatformSettingsEntity;
import mn.uziy.backend.domain.PlatformSettingsRepository;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

class PlatformSettingsServiceTest {

    private final PlatformSettingsRepository repo = mock(PlatformSettingsRepository.class);
    private final PlatformSettingsServiceImpl service = new PlatformSettingsServiceImpl(repo);
    private final JwtPrincipal admin = new JwtPrincipal(1L, Role.ADMIN);

    private PlatformSettingsEntity seed(int commission, int minReward) {
        PlatformSettingsEntity e = new PlatformSettingsEntity();
        e.setId(1);
        e.setCommissionPercent(commission);
        e.setMinRewardPerViewer(minReward);
        return e;
    }

    private PlatformSettingsEntity seed() {
        return seed(30, 100);
    }

    private ArgumentCaptor<PlatformSettingsEntity> stubSave() {
        ArgumentCaptor<PlatformSettingsEntity> saved = ArgumentCaptor.forClass(PlatformSettingsEntity.class);
        when(repo.save(saved.capture())).thenAnswer(inv -> inv.getArgument(0));
        return saved;
    }

    // ---- GET --------------------------------------------------------------

    @Test
    void getReturnsCommissionPercentAndMinimumReward() {
        when(repo.findById(1)).thenReturn(Optional.of(seed(30, 100)));
        PlatformSettingsDto dto = service.get();
        assertThat(dto.commissionPercent()).isEqualTo(30);
        assertThat(dto.minRewardPerViewer()).isEqualTo(100);
        assertThat(dto.updatedAt()).isNotNull();
    }

    @Test
    void getThrowsWhenTheSingletonRowIsMissing() {
        when(repo.findById(1)).thenReturn(Optional.empty());
        assertThatThrownBy(service::get).isInstanceOf(IllegalStateException.class);
    }

    // ---- PATCH ------------------------------------------------------------

    @Test
    void updatePersistsNewCommissionAndMinimumStampsUpdatedBy() {
        when(repo.findById(1)).thenReturn(Optional.of(seed()));
        ArgumentCaptor<PlatformSettingsEntity> saved = stubSave();

        PlatformSettingsDto dto = service.update(new UpdatePlatformSettingsReq(35, 250), admin.userId());

        assertThat(dto.commissionPercent()).isEqualTo(35);
        assertThat(dto.minRewardPerViewer()).isEqualTo(250);
        assertThat(saved.getValue().getCommissionPercent()).isEqualTo(35);
        assertThat(saved.getValue().getMinRewardPerViewer()).isEqualTo(250);
        assertThat(saved.getValue().getUpdatedBy()).isEqualTo(1L);
    }

    @ParameterizedTest
    @ValueSource(ints = {1, 90})
    void commissionBounds1And90AreAccepted(int commission) {
        when(repo.findById(1)).thenReturn(Optional.of(seed()));
        stubSave();
        assertThat(service.update(new UpdatePlatformSettingsReq(commission, 1), admin.userId()).commissionPercent())
                .isEqualTo(commission);
    }

    @ParameterizedTest
    @ValueSource(ints = {0, -5, 91, 100})
    void commissionOutside1To90Is400(int commission) {
        when(repo.findById(1)).thenReturn(Optional.of(seed()));
        var ex = assertFailsWithHttp(
                () -> service.update(new UpdatePlatformSettingsReq(commission, 100), admin.userId()));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(ex.reason()).isEqualTo(PlatformSettingsServiceImpl.COMMISSION_RANGE_MESSAGE);
        verify(repo, never()).save(any());
    }

    @ParameterizedTest
    @ValueSource(ints = {0, -1})
    void minimumRewardBelow1Is400(int minReward) {
        when(repo.findById(1)).thenReturn(Optional.of(seed()));
        var ex = assertFailsWithHttp(
                () -> service.update(new UpdatePlatformSettingsReq(30, minReward), admin.userId()));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(ex.reason()).isEqualTo(PlatformSettingsServiceImpl.MIN_REWARD_MESSAGE);
        verify(repo, never()).save(any());
    }

    @Test
    void missingFieldsAre400() {
        when(repo.findById(1)).thenReturn(Optional.of(seed()));
        var a = assertFailsWithHttp(
                () -> service.update(new UpdatePlatformSettingsReq(null, 100), admin.userId()));
        assertThat(a.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        var b = assertFailsWithHttp(
                () -> service.update(new UpdatePlatformSettingsReq(30, null), admin.userId()));
        assertThat(b.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
