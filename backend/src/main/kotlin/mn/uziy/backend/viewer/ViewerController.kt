package mn.uziy.backend.viewer

import jakarta.validation.Valid
import mn.uziy.backend.auth.Me
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*

/** HTTP adapter for the viewer app — all behaviour lives in the services. */
@RestController
@RequestMapping("/viewer")
@PreAuthorize("hasRole('VIEWER')")
class ViewerController(
    private val profile: ViewerService,
    private val rewards: RewardService,
) {

    @GetMapping("/me")
    fun me(@Auth principal: JwtPrincipal): Me = profile.me(principal.userId)

    @GetMapping("/feed")
    fun feed(@Auth principal: JwtPrincipal): List<FeedItemDto> = profile.feed(principal.userId)

    @GetMapping("/campaigns/{id}/questions")
    fun questions(@PathVariable id: Long): List<QuestionDto> = profile.questions(id)

    @PostMapping("/campaigns/{id}/submit")
    fun submit(
        @PathVariable id: Long,
        @Valid @RequestBody body: SubmitSurveyReq,
        @Auth principal: JwtPrincipal,
    ): RewardResult = rewards.submitSurvey(principal.userId, id, body.answers)
}
