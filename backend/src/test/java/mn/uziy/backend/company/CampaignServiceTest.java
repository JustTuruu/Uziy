package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyTestFixtures.PRINCIPAL;
import static mn.uziy.backend.company.CompanyTestFixtures.sampleCampaign;
import static mn.uziy.backend.company.CompanyTestFixtures.settings;
import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PlatformSettingsRepository;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.support.HttpAssertions.HttpFailure;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

class CampaignServiceTest {

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final SurveyQuestionRepository questions = mock(SurveyQuestionRepository.class);
    private final PlatformSettingsRepository platformSettings = mock(PlatformSettingsRepository.class);

    private final CampaignServiceImpl campaignSvc =
            new CampaignServiceImpl(campaigns, questions, platformSettings);
    private final long companyId = PRINCIPAL.userId();

    CampaignServiceTest() {
        settings(platformSettings, 30, 100);
    }

    private CreateCampaignReq videoReq(Double totalBudget, Integer targetViewers, Double rewardPerUser,
                                       int durationSeconds) {
        return new CreateCampaignReq(
                "Шинэ 5G", null, null, durationSeconds, TargetGender.ALL, 18, 45, "Улаанбаатар",
                totalBudget, targetViewers, rewardPerUser,
                List.of(new CreateCampaignReq.NewQuestion("P", "SINGLE_CHOICE", List.of("A", "B"), null)));
    }

    private CreateCampaignReq videoReq(Integer targetViewers, Double rewardPerUser) {
        return videoReq(1_000_000.0, targetViewers, rewardPerUser, 45);
    }

    private CreateCampaignReq viewers(int n) {
        return videoReq(n, null);
    }

    /** Stubs saves and returns a holder for the persisted campaign. */
    private AtomicReference<CampaignEntity> captureSave(long id) {
        AtomicReference<CampaignEntity> saved = new AtomicReference<>();
        when(campaigns.save(any(CampaignEntity.class))).thenAnswer(inv -> {
            CampaignEntity e = inv.getArgument(0);
            e.setId(id);
            saved.set(e);
            return e;
        });
        when(questions.save(any(SurveyQuestionEntity.class))).thenAnswer(inv -> inv.getArgument(0));
        return saved;
    }

    private AtomicReference<CampaignEntity> captureSave() {
        return captureSave(77L);
    }

    private void assertBadRequest(String message, Runnable block) {
        HttpFailure ex = assertFailsWithHttp(block);
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(ex.reason()).isEqualTo(message);
    }

    // ------- list / get ------------------------------------------------------

    @Nested
    class Read {

        @Test
        void listReturnsOnlyOwnCampaigns() {
            when(campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L))
                    .thenReturn(List.of(sampleCampaign(1), sampleCampaign(2)));
            assertThat(campaignSvc.list(companyId)).hasSize(2);
            verify(campaigns).findAllByCompanyIdOrderByCreatedAtDesc(500L);
        }

        @Test
        void getReturnsCampaignOwnedByCallerWithTheNewPricingFields() {
            when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1)));
            CampaignDto dto = campaignSvc.get(companyId, 1L);
            assertThat(dto.id()).isEqualTo(1L);
            assertThat(dto.targetViewers()).isEqualTo(1000);
            assertThat(dto.commissionPercent()).isEqualTo(30);
            assertThat(dto.paidAt()).isNull();
        }

        @Test
        void getThrows403ForCampaignOwnedByAnotherCompany() {
            when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1, 999L, CampaignStatus.ACTIVE)));
            HttpFailure ex = assertFailsWithHttp(() -> campaignSvc.get(companyId, 1L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        }

        @Test
        void getThrows404WhenCampaignNotFound() {
            when(campaigns.findById(any())).thenReturn(Optional.empty());
            HttpFailure ex = assertFailsWithHttp(() -> campaignSvc.get(companyId, 999L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        }
    }

    // ------- create ----------------------------------------------------------

    @Nested
    class Create {

        @Test
        void viewersMode1000000For1000ViewersSavesC1000R700InAwaitingPayment() {
            AtomicReference<CampaignEntity> saved = captureSave();
            CampaignDto dto = campaignSvc.create(companyId, viewers(1_000));

            assertThat(dto.id()).isEqualTo(77L);
            CampaignEntity c = saved.get();
            assertThat(c.getStatus()).isEqualTo(CampaignStatus.AWAITING_PAYMENT);
            assertThat(dto.status()).isEqualTo(CampaignStatus.AWAITING_PAYMENT);
            assertThat(c.getCompanyId()).isEqualTo(500L);
            assertThat(c.getTotalBudget()).isEqualTo(1_000_000.0);
            assertThat(c.getRemainingBudget()).isEqualTo(1_000_000.0);
            assertThat(c.getCostPerView()).isEqualTo(1000.0);
            assertThat(c.getRewardPerUser()).isEqualTo(700.0);
            assertThat(c.getTargetViewers()).isEqualTo(1000);
            assertThat(c.getCommissionPercent()).isEqualTo(30);
            assertThat(c.getPaidAt()).isNull();
            assertThat(dto.targetViewers()).isEqualTo(1000);
            assertThat(dto.commissionPercent()).isEqualTo(30);

            ArgumentCaptor<SurveyQuestionEntity> q = ArgumentCaptor.forClass(SurveyQuestionEntity.class);
            verify(questions, times(1)).save(q.capture());
            SurveyQuestionEntity sq = q.getValue();
            assertThat(sq.getCampaignId()).isEqualTo(77L);
            assertThat(sq.getPrompt()).isEqualTo("P");
            assertThat(sq.getQType()).isEqualTo("SINGLE_CHOICE");
            assertThat(sq.getPosition()).isEqualTo(1);
            assertThat(sq.getOptionsJson()).isEqualTo("[\"A\", \"B\"]");
        }

        @Test
        void viewersModeChargesOnlyThePayableAmountNotTheUnusedRemainder() {
            AtomicReference<CampaignEntity> saved = captureSave();
            campaignSvc.create(companyId, viewers(1_428));
            assertThat(saved.get().getTotalBudget()).isEqualTo(999_600.0);
            assertThat(saved.get().getRemainingBudget()).isEqualTo(999_600.0);
            assertThat(saved.get().getCostPerView()).isEqualTo(700.0);
            assertThat(saved.get().getRewardPerUser()).isEqualTo(490.0);
            assertThat(saved.get().getTargetViewers()).isEqualTo(1428);
        }

        @Test
        void rewardMode500PerViewerDerivesC715AndN1398() {
            AtomicReference<CampaignEntity> saved = captureSave();
            CampaignDto dto = campaignSvc.create(companyId, videoReq(null, 500.0));
            CampaignEntity c = saved.get();
            assertThat(c.getCostPerView()).isEqualTo(715.0);
            assertThat(c.getRewardPerUser()).isEqualTo(500.0);
            assertThat(c.getTargetViewers()).isEqualTo(1398);
            assertThat(c.getTotalBudget()).isEqualTo(999_570.0);
            assertThat(c.getRemainingBudget()).isEqualTo(999_570.0);
            assertThat(dto.status()).isEqualTo(CampaignStatus.AWAITING_PAYMENT);
        }

        @Test
        void usesTheCurrentPlatformCommissionAndSnapshotsIt() {
            settings(platformSettings, 35, 100);
            AtomicReference<CampaignEntity> saved = captureSave();
            campaignSvc.create(companyId, videoReq(500_000.0, 1_000, null, 45));
            assertThat(saved.get().getCostPerView()).isEqualTo(500.0);
            assertThat(saved.get().getRewardPerUser()).isEqualTo(325.0);
            assertThat(saved.get().getCommissionPercent()).isEqualTo(35);
        }

        @Test
        void bothTargetViewersAndRewardPerUserIs400() {
            assertBadRequest(CompanyMessages.EXACTLY_ONE_DRIVER_MESSAGE,
                    () -> campaignSvc.create(companyId, videoReq(1_000, 700.0)));
            verify(campaigns, never()).save(any());
        }

        @Test
        void neitherTargetViewersNorRewardPerUserIs400() {
            assertBadRequest("Үзэгчийн тоо эсвэл нэг үзэгчийн урамшууллын аль нэгийг оруулна уу",
                    () -> campaignSvc.create(companyId, videoReq(null, null)));
            verify(campaigns, never()).save(any());
        }

        @Test
        void budgetTooSmallIs400WithTheMongolianPricingMessage() {
            String msg = "Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү";
            assertBadRequest(msg,
                    () -> campaignSvc.create(companyId, videoReq(500.0, 1_000, null, 45)));
            assertBadRequest(msg,
                    () -> campaignSvc.create(companyId, videoReq(500.0, null, 700.0, 45)));
            verify(campaigns, never()).save(any());
        }

        @Test
        void rewardBelowTheAdminMinimumIs400AndNamesTheMinimum() {
            settings(platformSettings, 30, 150);
            String msg = "Нэг үзэгчид олгох урамшуулал хамгийн багадаа 150 ₮ байх ёстой";
            // 100,000 / 1,000 = 100 → R = 70 < 150
            assertBadRequest(msg,
                    () -> campaignSvc.create(companyId, videoReq(100_000.0, 1_000, null, 45)));
            assertBadRequest(msg, () -> campaignSvc.create(companyId, videoReq(null, 149.0)));
        }

        @Test
        void missingOrZeroBudgetIs400BudgetInvalid() {
            String msg = "Нийт төсвөө оруулна уу";
            assertBadRequest(msg, () -> campaignSvc.create(companyId, videoReq(null, 1_000, null, 45)));
            assertBadRequest(msg, () -> campaignSvc.create(companyId, videoReq(0.0, 1_000, null, 45)));
            assertBadRequest(msg, () -> campaignSvc.create(companyId, videoReq(-1.0, 1_000, null, 45)));
        }

        @Test
        void zeroViewersIs400ViewersInvalidZeroRewardIs400RewardInvalid() {
            assertBadRequest("Үзэгчийн тоогоо оруулна уу",
                    () -> campaignSvc.create(companyId, videoReq(0, null)));
            assertBadRequest("Нэг үзэгчид олгох урамшууллаа оруулна уу",
                    () -> campaignSvc.create(companyId, videoReq(null, 0.0)));
        }

        @Test
        void fractionalTogrogIs400() {
            assertBadRequest(CompanyMessages.WHOLE_TUGRIK_MESSAGE,
                    () -> campaignSvc.create(companyId, videoReq(1_000_000.5, 1_000, null, 45)));
            assertBadRequest(CompanyMessages.WHOLE_TUGRIK_MESSAGE,
                    () -> campaignSvc.create(companyId, videoReq(null, 700.25)));
        }

        @Test
        void absurdBudgetIs400InsteadOfOverflowing() {
            assertBadRequest(CompanyMessages.AMOUNT_TOO_LARGE_MESSAGE,
                    () -> campaignSvc.create(companyId, videoReq(1e18, 1_000, null, 45)));
        }

        @Test
        void rewardModeThatWouldNeedMoreViewersThanFitInAnIntIs400() {
            // 10^15 ₮ at 100 ₮ reward (C = 143) → ~7·10^12 viewers.
            assertBadRequest(CompanyMessages.TOO_MANY_VIEWERS_MESSAGE,
                    () -> campaignSvc.create(companyId, videoReq(1e15, null, 100.0, 45)));
        }

        @Test
        void serverComputedCostIsSavedTheClientCannotChooseCostPerView() {
            // CreateCampaignReq has no costPerView component at all; whatever the
            // client sends there is dropped by Jackson (see the integration
            // test for the JSON path). The saved price is always C from pricing.
            assertThat(Arrays.stream(CreateCampaignReq.class.getRecordComponents())
                    .map(RecordComponent::getName)).doesNotContain("costPerView");
            AtomicReference<CampaignEntity> saved = captureSave();
            campaignSvc.create(companyId, viewers(2_000));
            assertThat(saved.get().getCostPerView()).isEqualTo(500.0);
            assertThat(saved.get().getRewardPerUser()).isEqualTo(350.0);
        }

        @Test
        void videoCampaignWithDurationOutside5To180Is400() {
            assertBadRequest(CompanyMessages.DURATION_MESSAGE,
                    () -> campaignSvc.create(companyId, videoReq(1_000_000.0, 1_000, null, 3)));
            assertBadRequest(CompanyMessages.DURATION_MESSAGE,
                    () -> campaignSvc.create(companyId, videoReq(1_000_000.0, 1_000, null, 181)));
        }

        @Test
        void surveyOnlyCampaignUsesTheSamePricingBlanksVideoFields() {
            AtomicReference<CampaignEntity> saved = captureSave(88L);
            CreateCampaignReq body = new CreateCampaignReq(
                    "Судалгаа: Хэрэглэгчийн үзэл бодол", "should-be-ignored", false,
                    45, // forced to 0
                    null, null, null, null,
                    200_000.0, 500, null,
                    List.of(new CreateCampaignReq.NewQuestion(
                            "Танай брэндийг таньж байна уу?", "SINGLE_CHOICE",
                            List.of("Тийм", "Үгүй"), null)));
            CampaignDto dto = campaignSvc.create(companyId, body);

            assertThat(dto.id()).isEqualTo(88L);
            assertThat(dto.hasVideo()).isFalse();
            assertThat(saved.get().getDurationSeconds()).isEqualTo(0);
            assertThat(saved.get().getVideoUrl()).isEqualTo("");
            assertThat(saved.get().getCostPerView()).isEqualTo(400.0);   // 200,000 / 500
            assertThat(saved.get().getRewardPerUser()).isEqualTo(280.0); // 70 %
            assertThat(saved.get().getStatus()).isEqualTo(CampaignStatus.AWAITING_PAYMENT);
        }

        @Test
        void surveyOnlyCampaignWithNoQuestionsIs400() {
            CreateCampaignReq body = new CreateCampaignReq(
                    "empty-survey", null, false, null, null, null, null, null,
                    100_000.0, 100, null, null);
            assertBadRequest(CompanyMessages.NO_QUESTIONS_MESSAGE,
                    () -> campaignSvc.create(companyId, body));
        }
    }

    // ------- setStatus -------------------------------------------------------

    @Nested
    class SetStatus {

        @ParameterizedTest
        @CsvSource({
                "ACTIVE, PAUSED",
                "PAUSED, ACTIVE",
                "ACTIVE, COMPLETED",
                "PAUSED, COMPLETED",
        })
        void allowedCompanyTransitions(CampaignStatus from, CampaignStatus to) {
            when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1, 500L, from)));
            when(campaigns.tryTransition(eq(1L), eq(from), eq(to), any())).thenReturn(1);

            CampaignDto dto = campaignSvc.setStatus(companyId, 1L, to);

            assertThat(dto.status()).isEqualTo(to);
            verify(campaigns, times(1)).tryTransition(eq(1L), eq(from), eq(to), any());
            // Never a full-entity save: it would overwrite remaining_budget.
            verify(campaigns, never()).save(any());
        }

        @ParameterizedTest
        @CsvSource({
                "PENDING, ACTIVE",           // would skip moderation
                "AWAITING_PAYMENT, ACTIVE",  // would skip payment + moderation
                "AWAITING_PAYMENT, PENDING", // would skip payment
                "AWAITING_PAYMENT, PAUSED",
                "PENDING, PAUSED",
                "ACTIVE, PENDING",
                "ACTIVE, AWAITING_PAYMENT",
                "ACTIVE, REJECTED",
                "ACTIVE, ACTIVE",
                "COMPLETED, ACTIVE",
                "REJECTED, ACTIVE",
                "PAUSED, PAUSED",
        })
        void deniedCompanyTransitionsAre409(CampaignStatus from, CampaignStatus to) {
            when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1, 500L, from)));
            HttpFailure ex = assertFailsWithHttp(() -> campaignSvc.setStatus(companyId, 1L, to));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
            assertThat(ex.reason()).isEqualTo("Энэ төлөвөөс шилжих боломжгүй");
            verify(campaigns, never()).tryTransition(anyLong(), any(), any(), any());
        }

        @Test
        void conflict409WhenTheStatusChangedBetweenReadAndUpdate() {
            when(campaigns.findById(1L))
                    .thenReturn(Optional.of(sampleCampaign(1, 500L, CampaignStatus.PAUSED)));
            when(campaigns.tryTransition(eq(1L), eq(CampaignStatus.PAUSED), eq(CampaignStatus.ACTIVE), any()))
                    .thenReturn(0);
            HttpFailure ex = assertFailsWithHttp(
                    () -> campaignSvc.setStatus(companyId, 1L, CampaignStatus.ACTIVE));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        }

        @Test
        void forbidden403ForNonOwner() {
            when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1, 999L, CampaignStatus.ACTIVE)));
            HttpFailure ex = assertFailsWithHttp(
                    () -> campaignSvc.setStatus(companyId, 1L, CampaignStatus.PAUSED));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        }

        @Test
        void notFound404WhenMissing() {
            when(campaigns.findById(any())).thenReturn(Optional.empty());
            HttpFailure ex = assertFailsWithHttp(
                    () -> campaignSvc.setStatus(companyId, 1L, CampaignStatus.PAUSED));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        }
    }
}
