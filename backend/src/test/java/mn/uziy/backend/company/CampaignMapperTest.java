package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyTestFixtures.sampleCampaign;
import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PaymentProvider;
import mn.uziy.backend.domain.PaymentStatus;
import mn.uziy.backend.domain.TargetGender;
import org.junit.jupiter.api.Test;

class CampaignMapperTest {

    private final CampaignMapper mapper = new CampaignMapper();
    private final PaymentMapper paymentMapper = new PaymentMapper();

    @Test
    void mapsEveryCampaignField() {
        CampaignEntity c = sampleCampaign(5L, 500L, CampaignStatus.PENDING);
        c.setVideoUrl("http://v");
        c.setHasVideo(true);
        OffsetDateTime paid = OffsetDateTime.of(2026, 10, 1, 1, 2, 3, 0, ZoneOffset.UTC);
        c.setPaidAt(paid);

        CampaignDto dto = mapper.toDto(c);

        assertThat(dto.id()).isEqualTo(5L);
        assertThat(dto.title()).isEqualTo("T5");
        assertThat(dto.videoUrl()).isEqualTo("http://v");
        assertThat(dto.durationSeconds()).isEqualTo(30);
        assertThat(dto.hasVideo()).isTrue();
        assertThat(dto.targetGender()).isEqualTo(TargetGender.ALL);
        assertThat(dto.minAge()).isEqualTo(18);
        assertThat(dto.maxAge()).isEqualTo(45);
        assertThat(dto.targetCity()).isEqualTo("Улаанбаатар");
        assertThat(dto.totalBudget()).isEqualTo(1_000_000.0);
        assertThat(dto.remainingBudget()).isEqualTo(900_000.0);
        assertThat(dto.costPerView()).isEqualTo(1000.0);
        assertThat(dto.rewardPerUser()).isEqualTo(700.0);
        assertThat(dto.status()).isEqualTo(CampaignStatus.PENDING);
        assertThat(dto.targetViewers()).isEqualTo(1000);
        assertThat(dto.commissionPercent()).isEqualTo(30);
        assertThat(dto.paidAt()).isEqualTo(paid);
    }

    @Test
    void mapsPaymentFieldsAndTheGivenTitle() {
        OffsetDateTime at = OffsetDateTime.of(2026, 10, 1, 1, 2, 3, 0, ZoneOffset.UTC);
        CampaignPaymentEntity p = new CampaignPaymentEntity();
        p.setId(9L);
        p.setCampaignId(4L);
        p.setCompanyId(500L);
        p.setAmount(1234.0);
        p.setProvider(PaymentProvider.SIMULATED);
        p.setStatus(PaymentStatus.PAID);
        p.setReference("UZ-1");
        p.setCreatedAt(at);
        p.setPaidAt(at);

        PaymentDto dto = paymentMapper.toDto(p, "Title");

        assertThat(dto).isEqualTo(new PaymentDto(9L, 4L, "Title", 1234.0, PaymentProvider.SIMULATED,
                PaymentStatus.PAID, "UZ-1", at, at));
    }
}
