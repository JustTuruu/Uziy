package mn.uziy.backend.company

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.JwtPrincipal
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CompanyControllerTest {

    private val campaigns = mockk<CampaignRepository>()
    private val questions = mockk<SurveyQuestionRepository>()
    private val controller = CompanyController(campaigns, questions)

    private val principal = JwtPrincipal(userId = 500L, role = Role.COMPANY)

    private fun sampleCampaign(id: Long, ownerId: Long = 500L,
                               status: CampaignStatus = CampaignStatus.ACTIVE) =
        CampaignEntity(
            id = id, companyId = ownerId, title = "T",
            durationSeconds = 30, targetGender = TargetGender.ALL,
            minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
            totalBudget = 1_000_000.0, remainingBudget = 900_000.0,
            costPerView = 1000.0, rewardPerUser = 700.0, status = status,
        )

    // ------- list ----------------------------------------------------------

    @Test
    fun `list returns only own campaigns`() {
        every { campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L) } returns
                listOf(sampleCampaign(1), sampleCampaign(2))
        assertEquals(2, controller.list(principal).size)
    }

    // ------- get -----------------------------------------------------------

    @Test
    fun `get returns campaign owned by caller`() {
        every { campaigns.findById(1L) } returns Optional.of(sampleCampaign(1))
        val dto = controller.get(1L, principal)
        assertEquals(1L, dto.id)
    }

    @Test
    fun `get throws 403 for campaign owned by another company`() {
        every { campaigns.findById(1L) } returns Optional.of(
            sampleCampaign(1, ownerId = 999L),
        )
        val ex = assertFailsWith<ResponseStatusException> {
            controller.get(1L, principal)
        }
        assertEquals(HttpStatus.FORBIDDEN, ex.statusCode)
    }

    @Test
    fun `get throws 404 when campaign not found`() {
        every { campaigns.findById(any()) } returns Optional.empty()
        assertFailsWith<ResponseStatusException> {
            controller.get(999L, principal)
        }
    }

    // ------- create --------------------------------------------------------

    @Test
    fun `create persists campaign in PENDING status and saves questions`() {
        val saved = slot<CampaignEntity>()
        every { campaigns.save(capture(saved)) } answers {
            saved.captured.also { it.id = 77L }
        }
        every { questions.save(any()) } answers { firstArg() }

        val body = CreateCampaignReq(
            title = "Шинэ 5G",
            durationSeconds = 45,
            targetGender = TargetGender.ALL,
            minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
            totalBudget = 1_000_000.0,
            costPerView = 1000.0,
            rewardPerUser = 700.0,
            questions = listOf(
                CreateCampaignReq.NewQuestion(
                    prompt = "P", type = "SINGLE_CHOICE",
                    options = listOf("A", "B"),
                ),
            ),
        )
        val dto = controller.create(body, principal)

        assertEquals(77L, dto.id)
        assertEquals(CampaignStatus.PENDING, saved.captured.status)
        assertEquals(500L, saved.captured.companyId)
        assertEquals(1_000_000.0, saved.captured.remainingBudget)
        verify(exactly = 1) { questions.save(match {
            it.campaignId == 77L && it.prompt == "P" && it.qType == "SINGLE_CHOICE"
        }) }
    }

    @Test
    fun `create rejects reward greater than or equal to cost`() {
        val body = CreateCampaignReq(
            title = "bad", durationSeconds = 30,
            totalBudget = 100.0, costPerView = 500.0, rewardPerUser = 500.0,
        )
        val ex = assertFailsWith<ResponseStatusException> {
            controller.create(body, principal)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }

    @Test
    fun `create rejects video campaign with duration outside 5-180`() {
        val body = CreateCampaignReq(
            title = "bad-duration", hasVideo = true, durationSeconds = 3,
            totalBudget = 100_000.0, costPerView = 500.0, rewardPerUser = 300.0,
            questions = listOf(
                CreateCampaignReq.NewQuestion(prompt = "P", type = "TEXT"),
            ),
        )
        val ex = assertFailsWith<ResponseStatusException> {
            controller.create(body, principal)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }

    @Test
    fun `create allows survey-only campaign with duration=0 + no video url`() {
        val saved = slot<CampaignEntity>()
        every { campaigns.save(capture(saved)) } answers {
            saved.captured.also { it.id = 88L }
        }
        every { questions.save(any()) } answers { firstArg() }

        val body = CreateCampaignReq(
            title = "Судалгаа: Хэрэглэгчийн үзэл бодол",
            hasVideo = false, videoUrl = "should-be-ignored",
            durationSeconds = 45, // should be forced to 0
            totalBudget = 200_000.0,
            costPerView = 400.0, rewardPerUser = 250.0,
            questions = listOf(
                CreateCampaignReq.NewQuestion(
                    prompt = "Танай brand-ийг таньж байна уу?",
                    type = "SINGLE_CHOICE",
                    options = listOf("Тийм", "Үгүй"),
                ),
            ),
        )
        val dto = controller.create(body, principal)

        assertEquals(88L, dto.id)
        assertEquals(false, dto.hasVideo)
        assertEquals(0, saved.captured.durationSeconds)
        assertEquals("", saved.captured.videoUrl,
            "videoUrl must be blanked for survey-only campaigns")
    }

    @Test
    fun `create rejects survey-only campaign with no questions`() {
        val body = CreateCampaignReq(
            title = "empty-survey",
            hasVideo = false, videoUrl = "",
            durationSeconds = 0,
            totalBudget = 100_000.0,
            costPerView = 400.0, rewardPerUser = 250.0,
            questions = emptyList(),
        )
        val ex = assertFailsWith<ResponseStatusException> {
            controller.create(body, principal)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }

    // ------- setStatus -----------------------------------------------------

    @Test
    fun `setStatus updates status when owned by caller`() {
        val c = sampleCampaign(1, status = CampaignStatus.ACTIVE)
        every { campaigns.findById(1L) } returns Optional.of(c)
        every { campaigns.save(any()) } answers { firstArg() }

        val dto = controller.setStatus(1L, CampaignStatus.PAUSED, principal)
        assertEquals(CampaignStatus.PAUSED, dto.status)
    }

    @Test
    fun `setStatus throws 403 for non-owner`() {
        every { campaigns.findById(1L) } returns Optional.of(
            sampleCampaign(1, ownerId = 999L),
        )
        val ex = assertFailsWith<ResponseStatusException> {
            controller.setStatus(1L, CampaignStatus.PAUSED, principal)
        }
        assertEquals(HttpStatus.FORBIDDEN, ex.statusCode)
    }

    @Test
    fun `setStatus rejects invalid target status`() {
        every { campaigns.findById(1L) } returns Optional.of(sampleCampaign(1))
        val ex = assertFailsWith<ResponseStatusException> {
            // PENDING isn't a valid company-driven transition.
            controller.setStatus(1L, CampaignStatus.PENDING, principal)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }
}
