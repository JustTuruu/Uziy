package mn.uziy.backend.integration

import mn.uziy.backend.domain.*
import mn.uziy.backend.security.JwtPrincipal
import mn.uziy.backend.viewer.SubmitSurveyReq
import mn.uziy.backend.viewer.ViewerController
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import mn.uziy.backend.support.assertFailsWithHttp
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import java.time.LocalDate
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * The only spec §4C guarantee that mocks can't prove: that the SERIALIZABLE
 * reward transaction actually rolls back atomically against a real Postgres.
 *
 * Boots Spring against a fresh Postgres in Docker (Testcontainers), runs
 * Flyway migrations, then exercises the reward transaction directly through
 * the controller.
 */
@SpringBootTest
@Testcontainers
class AtomicRewardIntegrationTest {

    companion object {
        @Container
        @JvmStatic
        val postgres: PostgreSQLContainer<*> = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("zoos_test")
            .withUsername("test")
            .withPassword("test")

        @JvmStatic
        @DynamicPropertySource
        fun props(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }

    @Autowired lateinit var viewerController: ViewerController
    @Autowired lateinit var users: UserRepository
    @Autowired lateinit var campaigns: CampaignRepository
    @Autowired lateinit var questions: SurveyQuestionRepository
    @Autowired lateinit var history: ViewHistoryRepository
    @Autowired lateinit var encoder: PasswordEncoder

    /**
     * Populate the security context so @PreAuthorize("hasRole('VIEWER')")
     * lets the controller method run. We're calling through Spring's AOP
     * proxy, so the annotation is still enforced even though there's no HTTP
     * request.
     */
    private fun authAs(userId: Long, role: Role = Role.VIEWER) {
        val principal = JwtPrincipal(userId = userId, role = role)
        val auth = UsernamePasswordAuthenticationToken(
            principal, null,
            listOf(SimpleGrantedAuthority("ROLE_${role.name}")),
        )
        SecurityContextHolder.getContext().authentication = auth
    }

    @AfterEach fun clearAuth() { SecurityContextHolder.clearContext() }

    private fun freshViewer(phone: String): UserEntity =
        users.save(UserEntity(
            phoneNumber = phone,
            passwordHash = encoder.encode("password")!!,
            role = Role.VIEWER,
            gender = Gender.MALE,
            birthDate = LocalDate.now().minusYears(26),
            city = "Улаанбаатар",
            balance = 0.0,
        ))

    private fun freshActiveCampaign(companyId: Long,
                                    reward: Double = 700.0,
                                    cost: Double = 1000.0,
                                    budget: Double = 5_000_000.0): CampaignEntity =
        campaigns.save(CampaignEntity(
            companyId = companyId, title = "Test",
            durationSeconds = 30, targetGender = TargetGender.ALL,
            minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
            totalBudget = budget, remainingBudget = budget,
            costPerView = cost, rewardPerUser = reward,
            status = CampaignStatus.ACTIVE,
        )).also { c ->
            questions.save(SurveyQuestionEntity(
                campaignId = c.id!!, position = 1,
                prompt = "P", qType = "SINGLE_CHOICE",
                optionsJson = "[\"A\",\"B\"]", required = true,
            ))
        }

    @Test
    fun `submit credits reward, decrements budget, records history — all persisted`() {
        val company = users.save(UserEntity(
            phoneNumber = "80000001", passwordHash = "x", role = Role.COMPANY,
            companyName = "Co",
        ))
        val campaign = freshActiveCampaign(company.id!!)
        val viewer = freshViewer("70000001")
        val q = questions.findAllByCampaignIdOrderByPosition(campaign.id!!).first()

        authAs(viewer.id!!)
        val result = viewerController.submit(
            id = campaign.id!!,
            body = SubmitSurveyReq(listOf(
                SubmitSurveyReq.Answer(q.id!!, "\"A\""),
            )),
            principal = JwtPrincipal(userId = viewer.id!!, role = Role.VIEWER),
        )

        assertEquals(700.0, result.rewardPaid)
        assertEquals(700.0, result.newBalance)

        val reloadedUser = users.findById(viewer.id!!).orElseThrow()
        val reloadedCampaign = campaigns.findById(campaign.id!!).orElseThrow()
        assertEquals(700.0, reloadedUser.balance)
        assertEquals(4_999_000.0, reloadedCampaign.remainingBudget)
        assertTrue(history.existsByUserIdAndCampaignId(viewer.id!!, campaign.id!!))
    }

    @Test
    fun `submit twice for the same campaign is rejected — no double reward`() {
        val company = users.save(UserEntity(
            phoneNumber = "80000002", passwordHash = "x", role = Role.COMPANY,
            companyName = "Co",
        ))
        val campaign = freshActiveCampaign(company.id!!)
        val viewer = freshViewer("70000002")
        val q = questions.findAllByCampaignIdOrderByPosition(campaign.id!!).first()

        authAs(viewer.id!!)
        viewerController.submit(
            id = campaign.id!!,
            body = SubmitSurveyReq(listOf(SubmitSurveyReq.Answer(q.id!!, "\"A\""))),
            principal = JwtPrincipal(viewer.id!!, Role.VIEWER),
        )

        assertFailsWithHttp {
            viewerController.submit(
                id = campaign.id!!,
                body = SubmitSurveyReq(listOf(SubmitSurveyReq.Answer(q.id!!, "\"A\""))),
                principal = JwtPrincipal(viewer.id!!, Role.VIEWER),
            )
        }

        val reloadedUser = users.findById(viewer.id!!).orElseThrow()
        assertEquals(700.0, reloadedUser.balance, "reward should not have been paid twice")
    }

    @Test
    fun `submit fails when campaign budget is exhausted — no side effects`() {
        val company = users.save(UserEntity(
            phoneNumber = "80000003", passwordHash = "x", role = Role.COMPANY,
            companyName = "Co",
        ))
        // Budget exactly one view; drain it via a first viewer, then a second
        // viewer must fail.
        val campaign = freshActiveCampaign(company.id!!, budget = 1000.0)
        val q = questions.findAllByCampaignIdOrderByPosition(campaign.id!!).first()

        val first = freshViewer("70000003")
        authAs(first.id!!)
        viewerController.submit(
            id = campaign.id!!,
            body = SubmitSurveyReq(listOf(SubmitSurveyReq.Answer(q.id!!, "\"A\""))),
            principal = JwtPrincipal(first.id!!, Role.VIEWER),
        )

        val second = freshViewer("70000004")
        authAs(second.id!!)
        assertFailsWithHttp {
            viewerController.submit(
                id = campaign.id!!,
                body = SubmitSurveyReq(listOf(SubmitSurveyReq.Answer(q.id!!, "\"A\""))),
                principal = JwtPrincipal(second.id!!, Role.VIEWER),
            )
        }

        val reloadedSecond = users.findById(second.id!!).orElseThrow()
        val reloadedCampaign = campaigns.findById(campaign.id!!).orElseThrow()
        assertEquals(0.0, reloadedSecond.balance,
            "second viewer must not have been credited")
        assertEquals(0.0, reloadedCampaign.remainingBudget)
    }
}
