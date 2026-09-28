package mn.zoos.backend.auth

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size
import mn.zoos.backend.domain.*
import mn.zoos.backend.security.JwtService
import org.springframework.http.ResponseEntity
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import org.springframework.http.HttpStatus
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

@RestController
@RequestMapping("/auth")
class AuthController(
    private val users: UserRepository,
    private val encoder: PasswordEncoder,
    private val jwt: JwtService,
) {

    @PostMapping("/login")
    fun login(@Valid @RequestBody body: LoginReq): AuthResponse {
        val user = users.findByPhoneNumber(body.phoneNumber)
            ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials")
        if (!encoder.matches(body.password, user.passwordHash))
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials")
        return AuthResponse(token = jwt.issue(user), user = Me.of(user))
    }

    @PostMapping("/register/viewer")
    fun registerViewer(@Valid @RequestBody body: RegisterViewerReq): ResponseEntity<AuthResponse> {
        if (users.existsByPhoneNumber(body.phoneNumber))
            throw ResponseStatusException(HttpStatus.CONFLICT, "Phone already registered")
        val user = users.save(UserEntity(
            phoneNumber   = body.phoneNumber,
            passwordHash  = encoder.encode(body.password)!!,
            role          = Role.VIEWER,
            gender        = body.gender,
            birthDate     = body.birthDate,
            city          = body.city,
            district      = body.district,
        ))
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(AuthResponse(token = jwt.issue(user), user = Me.of(user)))
    }

    @PostMapping("/register/company")
    fun registerCompany(@Valid @RequestBody body: RegisterCompanyReq): ResponseEntity<AuthResponse> {
        if (users.existsByPhoneNumber(body.phoneNumber))
            throw ResponseStatusException(HttpStatus.CONFLICT, "Phone already registered")
        val user = users.save(UserEntity(
            phoneNumber   = body.phoneNumber,
            passwordHash  = encoder.encode(body.password)!!,
            role          = Role.COMPANY,
            companyName   = body.companyName,
        ))
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(AuthResponse(token = jwt.issue(user), user = Me.of(user)))
    }
}
