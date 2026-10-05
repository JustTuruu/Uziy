package mn.uziy.backend.integration

import mn.uziy.backend.admin.AdminController
import mn.uziy.backend.common.DomainException
import mn.uziy.backend.company.CompanyController
import mn.uziy.backend.company.CompanyMessages
import mn.uziy.backend.settings.PlatformSettingsServiceImpl
import mn.uziy.backend.web.ApiExceptionHandler
import mn.uziy.backend.company.CreateCampaignReq
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.JwtPrincipal
import mn.uziy.backend.security.JwtService
import mn.uziy.backend.settings.PlatformSettingsController
import mn.uziy.backend.settings.UpdatePlatformSettingsReq
import mn.uziy.backend.viewer.SubmitSurveyReq
import mn.uziy.backend.viewer.ViewerController
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.patch
import org.springframework.test.web.servlet.post
import mn.uziy.backend.support.assertFailsWithHttp
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import tools.jackson.databind.ObjectMapper
import java.util.concurrent.Callable
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Commission pricing + per-campaign payment against a real Postgres that
 * ran Flyway V1..V5 on top of the V2 dev seed (so V5's backfill ran over
 * existing campaigns). Controllers are called through their Spring proxies,
 * so @PreAuthorize and @Transactional are live.
 *
 * Seed ids used: admin 1, MobiCom (company) 2, Golomt Bank (company) 3,
 * viewer 100 (male, 24, Улаанбаатар).
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class CampaignPaymentFlowIntegrationTest {

    companion object {
        @Container
        @JvmStatic
        val postgres: PostgreSQLContainer<*> = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("uziy_payment_test")
            .withUsername("test")
            .withPassword("test")

        @JvmStatic
        @DynamicPropertySource
        fun props(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
            registry.add("uziy.payments.simulated") { "true" }
        }

        const val ADMIN = 1L
        const val MOBICOM = 2L
        const val GOLOMT = 3L
        const val VIEWER = 100L
    }

    @Autowired lateinit var company: CompanyController
    @Autowired lateinit var admin: AdminController
    @Autowired lateinit var viewer: ViewerController
    @Autowired lateinit var settings: PlatformSettingsController
    @Autowired lateinit var campaigns: CampaignRepository
    @Autowired lateinit var questions: SurveyQuestionRepository
    @Autowired lateinit var jdbc: JdbcTemplate
    @Autowired lateinit var json: ObjectMapper
    @Autowired lateinit var mvc: MockMvc
    @Autowired lateinit var jwt: JwtService
    @Autowired lateinit var users: UserRepository

    private fun bearer(userId: Long) = "Bearer " + jwt.issue(users.findById(userId).orElseThrow())

    private fun authAs(userId: Long, role: Role) {
        SecurityContextHolder.getContext().authentication = UsernamePasswordAuthenticationToken(
            JwtPrincipal(userId, role), null, listOf(SimpleGrantedAuthority("ROLE_${role.name}")),
        )
    }

    private fun principal(userId: Long, role: Role) = JwtPrincipal(userId, role)

    @AfterEach fun clearAuth() { SecurityContextHolder.clearContext() }

    private fun createReq(
        title: String = "Интеграцийн тест",
        totalBudget: Double = 1_000_000.0,
        targetViewers: Int? = 1_000,
        rewardPerUser: Double? = null,
    ) = CreateCampaignReq(
        title = title, hasVideo = true, videoUrl = "https://cdn.example/v.m3u8",
        durationSeconds = 30, targetGender = TargetGender.ALL,
        minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
        totalBudget = totalBudget, targetViewers = targetViewers, rewardPerUser = rewardPerUser,
        questions = listOf(CreateCampaignReq.NewQuestion(
            prompt = "Сонирхолтой санагдсан уу?", type = "SINGLE_CHOICE", options = listOf("Тийм", "Үгүй"),
        )),
    )

    private fun createAsMobiCom(req: CreateCampaignReq = createReq()) = run {
        authAs(MOBICOM, Role.COMPANY)
        company.create(req, principal(MOBICOM, Role.COMPANY))
    }

    private fun paidRows(campaignId: Long): Int = jdbc.queryForObject(
        "SELECT COUNT(*) FROM campaign_payments WHERE campaign_id = ? AND status = 'PAID'",
        Int::class.java, campaignId,
    )!!

    // --- migration over seeded data ---------------------------------------

    @Test
    fun `V5 backfilled the seeded campaigns and replaced the survey pricing columns`() {
        fun viewersOf(id: Long) = jdbc.queryForObject(
            "SELECT target_viewers FROM campaigns WHERE id = ?", Int::class.java, id)
        assertEquals(5000, viewersOf(1))  // 5,000,000 / 1000
        assertEquals(3750, viewersOf(2))  // 3,000,000 / 800
        assertEquals(3333, viewersOf(3))  // 4,000,000 / 1200, floored

        val legacy = campaigns.findById(3L).orElseThrow()
        assertEquals(CampaignStatus.PENDING, legacy.status, "seeded statuses are untouched")
        assertNull(legacy.commissionPercent)
        assertNull(legacy.paidAt)

        val s = settings.get()
        assertEquals(30, s.commissionPercent)
        assertEquals(100, s.minRewardPerViewer)
        val surveyCols = jdbc.queryForObject(
            """SELECT COUNT(*) FROM information_schema.columns
               WHERE table_name = 'platform_settings' AND column_name LIKE 'survey_only%'""",
            Int::class.java,
        )
        assertEquals(0, surveyCols)
    }

    // --- the whole happy path ---------------------------------------------

    @Test
    fun `create - pay - admin approves - viewer is rewarded`() {
        // 1. Company creates from JSON that still carries a stale costPerView:
        //    it must be ignored, the server prices with the platform commission.
        val body = json.readValue(
            """
            {"title":"5G багц","hasVideo":true,"videoUrl":"https://cdn.example/5g.m3u8",
             "durationSeconds":30,"targetGender":"ALL","minAge":18,"maxAge":45,
             "targetCity":"Улаанбаатар","totalBudget":1000000,"targetViewers":1000,
             "costPerView":1,
             "questions":[{"prompt":"Та 5G ашигладаг уу?","type":"SINGLE_CHOICE","options":["Тийм","Үгүй"]}]}
            """.trimIndent(),
            CreateCampaignReq::class.java,
        )
        authAs(MOBICOM, Role.COMPANY)
        val created = company.create(body, principal(MOBICOM, Role.COMPANY))
        assertEquals(CampaignStatus.AWAITING_PAYMENT, created.status)
        assertEquals(1000.0, created.costPerView)
        assertEquals(700.0, created.rewardPerUser)
        assertEquals(1000, created.targetViewers)
        assertEquals(30, created.commissionPercent)
        assertEquals(1_000_000.0, created.totalBudget)
        assertNull(created.paidAt)

        // 2. Unpaid → invisible to viewers, not moderatable, company can't self-activate.
        authAs(VIEWER, Role.VIEWER)
        assertTrue(viewer.feed(principal(VIEWER, Role.VIEWER)).none { it.id == created.id })

        authAs(ADMIN, Role.ADMIN)
        val unpaid = assertFailsWithHttp {
            admin.moderate(created.id, CampaignStatus.ACTIVE)
        }
        assertEquals(HttpStatus.CONFLICT, unpaid.statusCode)

        authAs(MOBICOM, Role.COMPANY)
        val selfActivate = assertFailsWithHttp {
            company.setStatus(created.id, CampaignStatus.ACTIVE, principal(MOBICOM, Role.COMPANY))
        }
        assertEquals(HttpStatus.CONFLICT, selfActivate.statusCode)

        // 3. Another company can neither pay for it nor see its payment.
        authAs(GOLOMT, Role.COMPANY)
        val foreign = assertFailsWithHttp {
            company.pay(created.id, principal(GOLOMT, Role.COMPANY))
        }
        assertEquals(HttpStatus.FORBIDDEN, foreign.statusCode)

        // 4. Owner pays.
        authAs(MOBICOM, Role.COMPANY)
        val paid = company.pay(created.id, principal(MOBICOM, Role.COMPANY))
        assertEquals(CampaignStatus.PENDING, paid.campaign.status)
        assertNotNull(paid.campaign.paidAt)
        assertEquals(1_000_000.0, paid.payment.amount)
        assertEquals(PaymentProvider.SIMULATED, paid.payment.provider)
        assertEquals(PaymentStatus.PAID, paid.payment.status)
        assertTrue(paid.payment.reference.matches(Regex("UZ-\\d{8}-${created.id}")))
        assertEquals("5G багц", paid.payment.campaignTitle)

        val stored = campaigns.findById(created.id).orElseThrow()
        assertEquals(CampaignStatus.PENDING, stored.status)
        assertNotNull(stored.paidAt)
        assertEquals(1_000_000.0, stored.remainingBudget, "paying must not touch the budget")
        assertEquals(1, paidRows(created.id))

        // Paying twice is a 409, still one PAID row.
        val twice = assertFailsWithHttp {
            company.pay(created.id, principal(MOBICOM, Role.COMPANY))
        }
        assertEquals(HttpStatus.CONFLICT, twice.statusCode)
        assertEquals(1, paidRows(created.id))

        // Payment history is scoped to the owner.
        assertTrue(company.payments(principal(MOBICOM, Role.COMPANY)).any { it.campaignId == created.id })
        authAs(GOLOMT, Role.COMPANY)
        assertTrue(company.payments(principal(GOLOMT, Role.COMPANY)).none { it.campaignId == created.id })

        // 5. PENDING is still not self-activatable — moderation can't be skipped.
        authAs(MOBICOM, Role.COMPANY)
        assertFailsWithHttp {
            company.setStatus(created.id, CampaignStatus.ACTIVE, principal(MOBICOM, Role.COMPANY))
        }

        // 6. Admin approves; the detail carries the snapshot + paidAt.
        authAs(ADMIN, Role.ADMIN)
        val approved = admin.moderate(created.id, CampaignStatus.ACTIVE)
        assertEquals(CampaignStatus.ACTIVE, approved.status)
        val detail = admin.getCampaign(created.id)
        assertEquals(30, detail.campaign.commissionPercent)
        assertNotNull(detail.campaign.paidAt)

        // 7. Viewer sees it and is rewarded R; budget drops by C.
        authAs(VIEWER, Role.VIEWER)
        assertTrue(viewer.feed(principal(VIEWER, Role.VIEWER)).any { it.id == created.id })
        val q = questions.findAllByCampaignIdOrderByPosition(created.id).single()
        val reward = viewer.submit(
            created.id,
            SubmitSurveyReq(listOf(SubmitSurveyReq.Answer(q.id!!, "\"Тийм\""))),
            principal(VIEWER, Role.VIEWER),
        )
        assertEquals(700.0, reward.rewardPaid)
        assertEquals(999_000.0, campaigns.findById(created.id).orElseThrow().remainingBudget)

        // 8. Company can now pause / resume / complete.
        authAs(MOBICOM, Role.COMPANY)
        val me = principal(MOBICOM, Role.COMPANY)
        assertEquals(CampaignStatus.PAUSED, company.setStatus(created.id, CampaignStatus.PAUSED, me).status)
        assertEquals(CampaignStatus.ACTIVE, company.setStatus(created.id, CampaignStatus.ACTIVE, me).status)
        assertEquals(CampaignStatus.COMPLETED, company.setStatus(created.id, CampaignStatus.COMPLETED, me).status)
        val after = campaigns.findById(created.id).orElseThrow()
        assertEquals(CampaignStatus.COMPLETED, after.status)
        assertEquals(999_000.0, after.remainingBudget, "status changes must not rewrite the budget")
    }

    @Test
    fun `REWARD mode is priced and charged server-side`() {
        val created = createAsMobiCom(createReq(targetViewers = null, rewardPerUser = 500.0))
        assertEquals(715.0, created.costPerView)
        assertEquals(1398, created.targetViewers)
        assertEquals(999_570.0, created.totalBudget)

        val paid = company.pay(created.id, principal(MOBICOM, Role.COMPANY))
        assertEquals(999_570.0, paid.payment.amount, "only P is charged, not the full B")
    }

    @Test
    fun `pricing errors are 400 with the Mongolian message and nothing is saved`() {
        val before = campaigns.count()
        authAs(MOBICOM, Role.COMPANY)
        val ex = assertFailsWithHttp {
            company.create(createReq(totalBudget = 500.0), principal(MOBICOM, Role.COMPANY))
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
        assertEquals("Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү", ex.reason)
        assertEquals(before, campaigns.count())
    }

    @Test
    fun `new campaigns use the commission the admin set`() {
        authAs(ADMIN, Role.ADMIN)
        settings.update(UpdatePlatformSettingsReq(35, 100), principal(ADMIN, Role.ADMIN))
        try {
            val created = createAsMobiCom(createReq(totalBudget = 500_000.0))
            assertEquals(500.0, created.costPerView)
            assertEquals(325.0, created.rewardPerUser)
            assertEquals(35, created.commissionPercent)
        } finally {
            authAs(ADMIN, Role.ADMIN)
            settings.update(UpdatePlatformSettingsReq(30, 100), principal(ADMIN, Role.ADMIN))
        }
    }

    // --- HTTP contract (JSON shapes the admin panel relies on) --------------

    @Test
    fun `HTTP - settings, create, pay, payments round trip with real JWTs`() {
        mvc.get("/platform-settings").andExpect {
            status { isOk() }
            jsonPath("$.commissionPercent") { value(30) }
            jsonPath("$.minRewardPerViewer") { value(100) }
            jsonPath("$.updatedAt") { exists() }
            jsonPath("$.surveyOnlyCostPerResponse") { doesNotExist() }
        }

        val createdJson = mvc.post("/company/campaigns") {
            header("Authorization", bearer(MOBICOM))
            contentType = MediaType.APPLICATION_JSON
            content = """
                {"title":"HTTP аян","hasVideo":false,"totalBudget":1000000,"rewardPerUser":700,
                 "costPerView":5,
                 "questions":[{"prompt":"Асуулт?","type":"TEXT"}]}
            """.trimIndent()
        }.andExpect {
            status { isOk() }
            jsonPath("$.status") { value("AWAITING_PAYMENT") }
            jsonPath("$.targetViewers") { value(1000) }
            jsonPath("$.costPerView") { value(1000.0) }
            jsonPath("$.rewardPerUser") { value(700.0) }
            jsonPath("$.totalBudget") { value(1_000_000.0) }
            jsonPath("$.commissionPercent") { value(30) }
            jsonPath("$.paidAt") { value(null as Any?) }
        }.andReturn().response.contentAsString
        val id = json.readTree(createdJson).get("id").asLong()

        mvc.post("/company/campaigns") {
            header("Authorization", bearer(MOBICOM))
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"x","durationSeconds":30,"totalBudget":1000000,"targetViewers":10,"rewardPerUser":700}"""
        }.andExpect {
            status { isBadRequest() }
            status { reason(CompanyMessages.EXACTLY_ONE_DRIVER_MESSAGE) }
        }

        mvc.post("/company/campaigns/$id/pay") {
            header("Authorization", bearer(GOLOMT))
        }.andExpect { status { isForbidden() } }

        mvc.post("/company/campaigns/$id/pay") {
            header("Authorization", bearer(MOBICOM))
        }.andExpect {
            status { isOk() }
            jsonPath("$.campaign.status") { value("PENDING") }
            jsonPath("$.campaign.paidAt") { exists() }
            jsonPath("$.payment.campaignId") { value(id) }
            jsonPath("$.payment.campaignTitle") { value("HTTP аян") }
            jsonPath("$.payment.amount") { value(1_000_000.0) }
            jsonPath("$.payment.provider") { value("SIMULATED") }
            jsonPath("$.payment.status") { value("PAID") }
            jsonPath("$.payment.reference") { value(org.hamcrest.Matchers.matchesPattern("UZ-\\d{8}-$id")) }
            jsonPath("$.payment.createdAt") { exists() }
            jsonPath("$.payment.paidAt") { exists() }
        }

        mvc.post("/company/campaigns/$id/pay") {
            header("Authorization", bearer(MOBICOM))
        }.andExpect {
            status { isConflict() }
            status { reason(CompanyMessages.NOT_PAYABLE_MESSAGE) }
        }

        mvc.get("/company/payments") {
            header("Authorization", bearer(MOBICOM))
        }.andExpect {
            status { isOk() }
            jsonPath("$[0].campaignId") { value(id) }
        }
        mvc.get("/company/payments") {
            header("Authorization", bearer(VIEWER))
        }.andExpect { status { isForbidden() } }

        mvc.patch("/company/campaigns/$id/status?status=ACTIVE") {
            header("Authorization", bearer(MOBICOM))
        }.andExpect {
            status { isConflict() }
            status { reason("Энэ төлөвөөс шилжих боломжгүй") }
        }

        mvc.patch("/admin/platform-settings") {
            header("Authorization", bearer(MOBICOM))
            contentType = MediaType.APPLICATION_JSON
            content = """{"commissionPercent":40,"minRewardPerViewer":100}"""
        }.andExpect { status { isForbidden() } }

        mvc.patch("/admin/platform-settings") {
            header("Authorization", bearer(ADMIN))
            contentType = MediaType.APPLICATION_JSON
            content = """{"commissionPercent":95,"minRewardPerViewer":100}"""
        }.andExpect {
            status { isBadRequest() }
            status { reason(PlatformSettingsServiceImpl.COMMISSION_RANGE_MESSAGE) }
        }
        assertEquals(30, settings.get().commissionPercent)
    }

    // --- races ---------------------------------------------------------------

    @Test
    fun `concurrent double pay - exactly one wins, exactly one PAID row`() {
        val threads = 4
        val pool = Executors.newFixedThreadPool(threads)
        try {
            repeat(5) { round ->
                val created = createAsMobiCom(createReq(title = "race-$round"))
                val barrier = CyclicBarrier(threads)
                val results = (1..threads).map {
                    pool.submit(Callable {
                        authAs(MOBICOM, Role.COMPANY)
                        try {
                            barrier.await(10, TimeUnit.SECONDS)
                            company.pay(created.id, principal(MOBICOM, Role.COMPANY))
                            "ok"
                        } catch (e: DomainException) {
                            ApiExceptionHandler.statusOf(e).value().toString()
                        } finally {
                            SecurityContextHolder.clearContext()
                        }
                    })
                }.map { it.get(30, TimeUnit.SECONDS) }

                assertEquals(1, results.count { it == "ok" }, "round $round: $results")
                assertEquals(threads - 1, results.count { it == "409" }, "round $round: $results")
                assertEquals(1, paidRows(created.id), "round $round")
                assertEquals(CampaignStatus.PENDING, campaigns.findById(created.id).orElseThrow().status)
            }
        } finally {
            pool.shutdownNow()
        }
    }

    @Test
    fun `the partial unique index rejects a second PAID row even if the app is bypassed`() {
        val created = createAsMobiCom()
        company.pay(created.id, principal(MOBICOM, Role.COMPANY))
        assertFailsWith<DataIntegrityViolationException> {
            jdbc.update(
                """INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                   VALUES (?, ?, 1, 'SIMULATED', 'PAID', ?)""",
                created.id, MOBICOM, "UZ-X-${created.id}",
            )
        }
        assertEquals(1, paidRows(created.id))
    }
}
