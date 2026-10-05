package mn.uziy.backend.viewer

import io.mockk.every
import io.mockk.mockk
import mn.uziy.backend.auth.Me
import mn.uziy.backend.domain.Role
import mn.uziy.backend.security.JwtPrincipal
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertSame

/** The controller is an adapter: it passes the caller's id to the services and nothing more. */
class ViewerControllerTest {

    private val profile = mockk<ViewerService>()
    private val rewards = mockk<RewardService>()
    private val controller = ViewerController(profile, rewards)
    private val principal = JwtPrincipal(userId = 42L, role = Role.VIEWER)

    @Test
    fun `me and feed use the caller's id`() {
        val me = Me(42L, "77000001", Role.VIEWER, null, null, null, 0.0, false, null)
        every { profile.me(42L) } returns me
        every { profile.feed(42L) } returns emptyList()

        assertSame(me, controller.me(principal))
        assertEquals(emptyList(), controller.feed(principal))
    }

    @Test
    fun `questions delegates by campaign id`() {
        every { profile.questions(7L) } returns emptyList()
        assertEquals(emptyList(), controller.questions(7L))
    }

    @Test
    fun `submit hands the caller's id, campaign and answers to the reward service`() {
        val answers = listOf(SubmitSurveyReq.Answer(10L, "\"Тийм\""))
        val result = RewardResult(rewardPaid = 700.0, newBalance = 700.0)
        every { rewards.submitSurvey(42L, 1L, answers) } returns result

        assertSame(result, controller.submit(1L, SubmitSurveyReq(answers), principal))
    }
}
