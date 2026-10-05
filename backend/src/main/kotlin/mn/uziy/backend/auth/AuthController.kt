package mn.uziy.backend.auth

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size
import mn.uziy.backend.domain.*
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.time.LocalDate

data class LoginReq(
    @field:Pattern(regexp = "\\d{8}", message = "8 digits")
    val phoneNumber: String,
    @field:NotBlank val password: String,
)

data class RegisterViewerReq(
    @field:Pattern(regexp = "\\d{8}") val phoneNumber: String,
    @field:Size(min = 6, max = 100) val password: String,
    val gender: Gender,
    val birthDate: LocalDate,
    @field:Size(max = 50) val city: String,
    @field:Size(max = 50) val district: String? = null,
)

data class RegisterCompanyReq(
    @field:Pattern(regexp = "\\d{8}") val phoneNumber: String,
    @field:Size(min = 6, max = 100) val password: String,
    @field:NotBlank @field:Size(max = 120) val companyName: String,
)

data class AuthResponse(
    val token: String,
    val user: Me,
)

data class Me(
    val id: Long,
    val phoneNumber: String,
    val role: Role,
    val gender: Gender?,
    val age: Int?,
    val city: String?,
    val balance: Double,
    val isVerified: Boolean,
    val companyName: String?,
) {
    companion object {
        fun of(u: UserEntity) = Me(
            id = u.id!!,
            phoneNumber = u.phoneNumber,
            role = u.role,
            gender = u.gender,
            age = u.age,
            city = u.city,
            balance = u.balance,
            isVerified = u.isVerified,
            companyName = u.companyName,
        )
    }
}

/** HTTP adapter only — credential checking and account creation live in [AuthService]. */
@RestController
@RequestMapping("/auth")
class AuthController(private val auth: AuthService) {

    @PostMapping("/login")
    fun login(@Valid @RequestBody body: LoginReq): AuthResponse = auth.login(body)

    @PostMapping("/register/viewer")
    fun registerViewer(@Valid @RequestBody body: RegisterViewerReq): ResponseEntity<AuthResponse> =
        ResponseEntity.status(HttpStatus.CREATED).body(auth.registerViewer(body))

    @PostMapping("/register/company")
    fun registerCompany(@Valid @RequestBody body: RegisterCompanyReq): ResponseEntity<AuthResponse> =
        ResponseEntity.status(HttpStatus.CREATED).body(auth.registerCompany(body))
}
