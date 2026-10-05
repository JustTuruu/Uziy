package mn.uziy.backend.auth

import mn.uziy.backend.common.ConflictException
import mn.uziy.backend.common.UnauthorizedException
import mn.uziy.backend.domain.Role
import mn.uziy.backend.domain.UserEntity
import mn.uziy.backend.domain.UserRepository
import mn.uziy.backend.security.JwtService
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service

/** Authentication and self-registration use cases. */
interface AuthService {
    fun login(req: LoginReq): AuthResponse
    fun registerViewer(req: RegisterViewerReq): AuthResponse
    fun registerCompany(req: RegisterCompanyReq): AuthResponse
}

@Service
class AuthServiceImpl(
    private val users: UserRepository,
    private val encoder: PasswordEncoder,
    private val jwt: JwtService,
) : AuthService {

    override fun login(req: LoginReq): AuthResponse {
        val user = users.findByPhoneNumber(req.phoneNumber)
            ?: throw UnauthorizedException(INVALID_CREDENTIALS)
        if (!encoder.matches(req.password, user.passwordHash))
            throw UnauthorizedException(INVALID_CREDENTIALS)
        return respond(user)
    }

    override fun registerViewer(req: RegisterViewerReq): AuthResponse {
        requirePhoneFree(req.phoneNumber)
        return respond(users.save(UserEntity(
            phoneNumber   = req.phoneNumber,
            passwordHash  = encoder.encode(req.password)!!,
            role          = Role.VIEWER,
            gender        = req.gender,
            birthDate     = req.birthDate,
            city          = req.city,
            district      = req.district,
        )))
    }

    override fun registerCompany(req: RegisterCompanyReq): AuthResponse {
        requirePhoneFree(req.phoneNumber)
        return respond(users.save(UserEntity(
            phoneNumber   = req.phoneNumber,
            passwordHash  = encoder.encode(req.password)!!,
            role          = Role.COMPANY,
            companyName   = req.companyName,
        )))
    }

    private fun requirePhoneFree(phone: String) {
        if (users.existsByPhoneNumber(phone)) throw ConflictException("Phone already registered")
    }

    private fun respond(user: UserEntity) = AuthResponse(token = jwt.issue(user), user = Me.of(user))

    companion object {
        const val INVALID_CREDENTIALS = "Invalid credentials"
    }
}
