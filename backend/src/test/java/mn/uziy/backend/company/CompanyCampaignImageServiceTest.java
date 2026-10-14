package mn.uziy.backend.company;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Optional;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.ForbiddenException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.media.CampaignImageService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.mock.web.MockMultipartFile;

class CompanyCampaignImageServiceTest {

    private static final long COMPANY = 2L;
    private static final long CAMPAIGN = 7L;

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final CampaignImageService images = mock(CampaignImageService.class);
    private final CompanyCampaignImageServiceImpl service = new CompanyCampaignImageServiceImpl(campaigns, images);
    private final MockMultipartFile file = new MockMultipartFile("file", "a.png", "image/png", new byte[] {1});

    private void stored(long owner, CampaignStatus status) {
        CampaignEntity c = new CampaignEntity();
        c.setId(CAMPAIGN);
        c.setCompanyId(owner);
        c.setStatus(status);
        when(campaigns.findById(CAMPAIGN)).thenReturn(Optional.of(c));
    }

    @ParameterizedTest
    @EnumSource(value = CampaignStatus.class, names = {"AWAITING_PAYMENT", "PENDING"})
    void beforeApprovalTheOwnerCanSetTheCover(CampaignStatus status) {
        stored(COMPANY, status);
        when(images.upload(CAMPAIGN, file)).thenReturn("/public/campaigns/7/image?v=1");

        assertThat(service.upload(COMPANY, CAMPAIGN, file)).isEqualTo("/public/campaigns/7/image?v=1");
    }

    @ParameterizedTest
    @EnumSource(value = CampaignStatus.class, names = {"ACTIVE", "PAUSED", "COMPLETED", "REJECTED"})
    void onceApprovedOrClosedTheCoverIsLockedForTheCompany(CampaignStatus status) {
        stored(COMPANY, status);

        assertThatThrownBy(() -> service.upload(COMPANY, CAMPAIGN, file))
                .isInstanceOf(ConflictException.class)
                .hasMessage(CompanyCampaignImageServiceImpl.LOCKED);
        assertThatThrownBy(() -> service.remove(COMPANY, CAMPAIGN)).isInstanceOf(ConflictException.class);
        verifyNoInteractions(images);
    }

    @Test
    void anotherCompanysSurveyIsForbidden() {
        stored(99L, CampaignStatus.PENDING);

        assertThatThrownBy(() -> service.upload(COMPANY, CAMPAIGN, file)).isInstanceOf(ForbiddenException.class);
        assertThatThrownBy(() -> service.remove(COMPANY, CAMPAIGN)).isInstanceOf(ForbiddenException.class);
        verifyNoInteractions(images);
    }

    @Test
    void anUnknownSurveyIs404() {
        when(campaigns.findById(CAMPAIGN)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.upload(COMPANY, CAMPAIGN, file)).isInstanceOf(NotFoundException.class);
    }

    @Test
    void theOwnerCanRemoveTheCoverBeforeApproval() {
        stored(COMPANY, CampaignStatus.AWAITING_PAYMENT);

        service.remove(COMPANY, CAMPAIGN);

        verify(images).remove(CAMPAIGN);
    }
}
