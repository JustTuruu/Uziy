package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyTestFixtures.sampleCampaign;
import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PaymentProvider;
import mn.uziy.backend.domain.PaymentStatus;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.pricing.CampaignPricing;
import mn.uziy.backend.pricing.PricingMode;
import mn.uziy.backend.pricing.PricingResult;
import org.junit.jupiter.api.Test;

class CampaignFactoryTest {

    private final CampaignFactory factory = new CampaignFactory();

    private PricingResult pricing() {
        return CampaignPricing.compute(PricingMode.VIEWERS, 1_000_000L, 30, 100L, 1_000L, null);
    }

    private CreateCampaignReq req(boolean hasVideo) {
        return new CreateCampaignReq("Шинэ", "http://v", hasVideo, 45, TargetGender.ALL, 18, 45, "Улаанбаатар",
                1_000_000.0, 1_000, null, List.of());
    }

    @Test
    void newVideoCampaignCarriesPricingAndStartsAwaitingPayment() {
        CampaignEntity c = factory.newCampaign(500L, req(true), pricing());

        assertThat(c.getCompanyId()).isEqualTo(500L);
        assertThat(c.getTitle()).isEqualTo("Шинэ");
        assertThat(c.getVideoUrl()).isEqualTo("http://v");
        assertThat(c.getDurationSeconds()).isEqualTo(45);
        assertThat(c.hasVideo()).isTrue();
        assertThat(c.getTotalBudget()).isEqualTo(1_000_000.0);
        assertThat(c.getRemainingBudget()).isEqualTo(1_000_000.0);
        assertThat(c.getCostPerView()).isEqualTo(1000.0);
        assertThat(c.getRewardPerUser()).isEqualTo(700.0);
        assertThat(c.getTargetViewers()).isEqualTo(1000);
        assertThat(c.getCommissionPercent()).isEqualTo(30);
        assertThat(c.getStatus()).isEqualTo(CampaignStatus.AWAITING_PAYMENT);
    }

    @Test
    void surveyOnlyCampaignBlanksVideoFields() {
        CampaignEntity c = factory.newCampaign(500L, req(false), pricing());
        assertThat(c.hasVideo()).isFalse();
        assertThat(c.getVideoUrl()).isEmpty();
        assertThat(c.getDurationSeconds()).isZero();
    }

    @Test
    void newQuestionsAreNumberedFromOneAndEncodeOptionsAsJson() {
        List<SurveyQuestionEntity> qs = factory.newQuestions(7L, List.of(
                new CreateCampaignReq.NewQuestion("P1", "SINGLE_CHOICE", List.of("A", "B\"q"), false),
                new CreateCampaignReq.NewQuestion("P2", "TEXT")));

        assertThat(qs).hasSize(2);
        assertThat(qs.get(0).getCampaignId()).isEqualTo(7L);
        assertThat(qs.get(0).getPosition()).isEqualTo(1);
        assertThat(qs.get(0).getOptionsJson()).isEqualTo("[\"A\", \"B\\\"q\"]");
        assertThat(qs.get(0).isRequired()).isFalse();
        assertThat(qs.get(1).getPosition()).isEqualTo(2);
        assertThat(qs.get(1).getOptionsJson()).isEqualTo("[]");
        assertThat(qs.get(1).isRequired()).isTrue();
    }

    @Test
    void newPaidPaymentCopiesTheCampaignBudgetAndMarksPaid() {
        OffsetDateTime at = OffsetDateTime.of(2026, 10, 1, 1, 2, 3, 0, ZoneOffset.UTC);
        CampaignPaymentEntity p = factory.newPaidPayment(sampleCampaign(42L), PaymentProvider.SIMULATED, "UZ-1", at);

        assertThat(p.getCampaignId()).isEqualTo(42L);
        assertThat(p.getCompanyId()).isEqualTo(500L);
        assertThat(p.getAmount()).isEqualTo(1_000_000.0);
        assertThat(p.getProvider()).isEqualTo(PaymentProvider.SIMULATED);
        assertThat(p.getStatus()).isEqualTo(PaymentStatus.PAID);
        assertThat(p.getReference()).isEqualTo("UZ-1");
        assertThat(p.getCreatedAt()).isEqualTo(at);
        assertThat(p.getPaidAt()).isEqualTo(at);
    }
}
