package mn.uziy.backend.viewer

import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.JwtPrincipal
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDate
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class ViewerControllerTest {

    private val users = mockk<UserRepository>()
    private val campaigns = mockk<CampaignRepository>()
    private val questions = mockk<SurveyQuestionRepository>()
    private val history = mockk<ViewHistoryRepository>()
    private val responses = mockk<SurveyResponseRepository>()

    private val controller = ViewerController(users, campaigns, questions, history, responses)

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

    private val principal = JwtPrincipal(userId = 42L, role = Role.VIEWER)

    private fun sampleCampaign(id: Long, reward: Double = 700.0, cost: Double = 1000.0) =
        CampaignEntity(
            id = id, companyId = 500L, title = "Test",
            durationSeconds = 30, targetGender = TargetGender.ALL,
            minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
            totalBudget = 5_000_000.0, remainingBudget = 5_000_000.0,
            costPerView = cost, rewardPerUser = reward,
            status = CampaignStatus.ACTIVE,
        )

    // ------- me ------------------------------------------------------------

    @Test
    fun `me returns the current user`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        val me = controller.me(principal)
        assertEquals(42L, me.id)
        assertEquals(Role.VIEWER, me.role)
    }

    // ------- feed ----------------------------------------------------------

    @Test
    fun `feed returns matching campaigns with company names`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        val c = sampleCampaign(1)
        every {
            campaigns.findFeedFor(42L, TargetGender.MALE, 26, "Улаанбаатар")
        } returns listOf(c)
        val company = UserEntity(id = 500L, phoneNumber = "1", passwordHash = "x",
            role = Role.COMPANY, companyName = "MobiCom")
        every { users.findAllById(listOf(500L)) } returns listOf(company)

        val feed = controller.feed(principal)

        assertEquals(1, feed.size)
        assertEquals(1L, feed[0].id)
        assertEquals("MobiCom", feed[0].companyName)
    }

    @Test
    fun `feed returns empty when viewer profile is incomplete`() {
        val bare = viewer.apply { gender = null; birthDate = null; city = null }
        every { users.findById(42L) } returns Optional.of(bare)
        assertTrue(controller.feed(principal).isEmpty())
    }

    @Test
    fun `feed returns empty list when no campaigns match`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        every { campaigns.findFeedFor(any(), any(), any(), any()) } returns emptyList()
        every { users.findAllById(emptyList()) } returns emptyList()
        assertTrue(controller.feed(principal).isEmpty())
    }

    // ------- questions -----------------------------------------------------

    @Test
    fun `questions returns ordered survey questions with parsed options`() {
        every { questions.findAllByCampaignIdOrderByPosition(1L) } returns listOf(
            SurveyQuestionEntity(id = 10L, campaignId = 1L, position = 1,
                prompt = "P1", qType = "SINGLE_CHOICE",
                optionsJson = "[\"A\",\"B\",\"C\"]", required = true),
            SurveyQuestionEntity(id = 11L, campaignId = 1L, position = 2,
                prompt = "P2", qType = "TEXT", optionsJson = "[]", required = false),
        )
        val qs = controller.questions(1L)
        assertEquals(2, qs.size)
        assertEquals(listOf("A", "B", "C"), qs[0].options)
        assertEquals(emptyList(), qs[1].options)
        assertEquals("TEXT", qs[1].type)
    }

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

        val result = controller.submit(
            id = 1L,
            body = SubmitSurveyReq(listOf(
                SubmitSurveyReq.Answer(10L, "\"Тийм\""),
                SubmitSurveyReq.Answer(999L, "\"ignored — not a real question\""),
            )),
            principal = principal,
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
        val ex = assertFailsWith<ResponseStatusException> {
            controller.submit(1L, SubmitSurveyReq(listOf(
                SubmitSurveyReq.Answer(1L, "\"x\""))), principal)
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
        verify(exactly = 0) { campaigns.tryDecrementBudget(any()) }
    }

    @Test
    fun `submit throws 404 when the campaign does not exist`() {
        every { history.existsByUserIdAndCampaignId(42L, 999L) } returns false
        every { campaigns.findById(999L) } returns Optional.empty()
        val ex = assertFailsWith<ResponseStatusException> {
            controller.submit(999L, SubmitSurveyReq(listOf(
                SubmitSurveyReq.Answer(1L, "\"x\""))), principal)
        }
        assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
    }

    @Test
    fun `submit throws 409 when tryDecrementBudget returns 0 (race, paused, or out of budget)`() {
        val c = sampleCampaign(1)
        every { history.existsByUserIdAndCampaignId(42L, 1L) } returns false
        every { campaigns.findById(1L) } returns Optional.of(c)
        every { campaigns.tryDecrementBudget(1L) } returns 0

        val ex = assertFailsWith<ResponseStatusException> {
            controller.submit(1L, SubmitSurveyReq(listOf(
                SubmitSurveyReq.Answer(1L, "\"x\""))), principal)
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
        // No view_history or balance mutation should have happened.
        verify(exactly = 0) { history.save(any()) }
        verify(exactly = 0) { users.save(any()) }
    }
}
