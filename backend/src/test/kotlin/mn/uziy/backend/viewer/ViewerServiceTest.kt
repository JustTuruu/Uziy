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

class ViewerServiceTest {

    private val users = mockk<UserRepository>()
    private val campaigns = mockk<CampaignRepository>()
    private val questions = mockk<SurveyQuestionRepository>()

    private val service = ViewerServiceImpl(users, campaigns, questions)

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

    // ------- me ------------------------------------------------------------

    @Test
    fun `me returns the current user`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        val me = service.me(42L)
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

        val feed = service.feed(42L)

        assertEquals(1, feed.size)
        assertEquals(1L, feed[0].id)
        assertEquals("MobiCom", feed[0].companyName)
    }

    @Test
    fun `feed returns empty when viewer profile is incomplete`() {
        val bare = viewer.apply { gender = null; birthDate = null; city = null }
        every { users.findById(42L) } returns Optional.of(bare)
        assertTrue(service.feed(42L).isEmpty())
    }

    @Test
    fun `feed returns empty list when no campaigns match`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        every { campaigns.findFeedFor(any(), any(), any(), any()) } returns emptyList()
        every { users.findAllById(emptyList()) } returns emptyList()
        assertTrue(service.feed(42L).isEmpty())
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
        val qs = service.questions(1L)
        assertEquals(2, qs.size)
        assertEquals(listOf("A", "B", "C"), qs[0].options)
        assertEquals(emptyList(), qs[1].options)
        assertEquals("TEXT", qs[1].type)
    }
}
