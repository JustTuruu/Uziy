package mn.uziy.backend.viewer

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import mn.uziy.backend.domain.*
import mn.uziy.backend.support.assertFailsWithHttp
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import java.time.LocalDate
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class RewardServiceTest {

    private val users = mockk<UserRepository>()
    private val campaigns = mockk<CampaignRepository>()
    private val questions = mockk<SurveyQuestionRepository>()
    private val history = mockk<ViewHistoryRepository>()
    private val responses = mockk<SurveyResponseRepository>()

    private val service = RewardServiceImpl(users, campaigns, questions, history, responses)

    private val viewer = UserEntity(
        id = 42L,
        phoneNumber = "77000001",
        passwordHash = "x",
        role = Role.VIEWER,
        gender = Gender.MALE,
        birthDate = LocalDate.now().minusYears(26),
        city = "Улаанбаатар",
        balance = 0.0,
    )

    private fun sampleCampaign(id: Long, reward: Double = 700.0, cost: Double = 1000.0) =
        CampaignEntity(
            id = id, companyId = 500L, title = "Test",
            durationSeconds = 30, targetGender = TargetGender.ALL,
            minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
            totalBudget = 5_000_000.0, remainingBudget = 5_000_000.0,
            costPerView = cost, rewardPerUser = reward,
            status = CampaignStatus.ACTIVE,
        )

    // ------- submit (the atomic reward transaction) ------------------------

    @Test
    fun `submit credits reward, marks view, and returns new balance`() {
        val c = sampleCampaign(1)
        every { history.existsByUserIdAndCampaignId(42L, 1L) } returns false
        every { campaigns.findById(1L) } returns Optional.of(c)
        every { campaigns.tryDecrementBudget(1L) } returns 1

        val savedView = ViewHistoryEntity(
            id = 999L, userId = 42L, campaignId = 1L, rewardPaid = 700.0,
        )
        every { history.save(any()) } returns savedView
        every { questions.findAllByCampaignIdOrderByPosition(1L) } returns listOf(
            SurveyQuestionEntity(id = 10L, campaignId = 1L, position = 1,
                prompt = "P", qType = "SINGLE_CHOICE",
                optionsJson = "[]", required = true),
        )
        every { responses.save(any()) } answers { firstArg() }
        every { users.findById(42L) } returns Optional.of(viewer)
        val saved = slot<UserEntity>()
        every { users.save(capture(saved)) } answers { saved.captured }

        val result = service.submitSurvey(
            userId = 42L,
            campaignId = 1L,
            answers = listOf(
                SubmitSurveyReq.Answer(10L, "\"Тийм\""),
                SubmitSurveyReq.Answer(999L, "\"ignored — not a real question\""),
            ),
        )

        assertEquals(700.0, result.rewardPaid)
        assertEquals(700.0, result.newBalance)
        assertEquals(700.0, saved.captured.balance)
        // Only the real question's answer should have been persisted (1 call, not 2).
        verify(exactly = 1) { responses.save(any()) }
    }

    @Test
    fun `submit throws 409 when the user already watched this campaign`() {
        every { history.existsByUserIdAndCampaignId(42L, 1L) } returns true
        val ex = assertFailsWithHttp {
            service.submitSurvey(42L, 1L, listOf(SubmitSurveyReq.Answer(1L, "\"x\"")))
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
        verify(exactly = 0) { campaigns.tryDecrementBudget(any()) }
    }

    @Test
    fun `submit throws 404 when the campaign does not exist`() {
        every { history.existsByUserIdAndCampaignId(42L, 999L) } returns false
        every { campaigns.findById(999L) } returns Optional.empty()
        val ex = assertFailsWithHttp {
            service.submitSurvey(42L, 999L, listOf(SubmitSurveyReq.Answer(1L, "\"x\"")))
        }
        assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
    }

    @Test
    fun `submit throws 409 when tryDecrementBudget returns 0 (race, paused, or out of budget)`() {
        val c = sampleCampaign(1)
        every { history.existsByUserIdAndCampaignId(42L, 1L) } returns false
        every { campaigns.findById(1L) } returns Optional.of(c)
        every { campaigns.tryDecrementBudget(1L) } returns 0

        val ex = assertFailsWithHttp {
            service.submitSurvey(42L, 1L, listOf(SubmitSurveyReq.Answer(1L, "\"x\"")))
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
        // No view_history or balance mutation should have happened.
        verify(exactly = 0) { history.save(any()) }
        verify(exactly = 0) { users.save(any()) }
    }
}
