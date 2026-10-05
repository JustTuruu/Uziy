package mn.uziy.backend.admin

import mn.uziy.backend.common.NotFoundException
import mn.uziy.backend.domain.UserRepository
import org.springframework.stereotype.Service

/** The admin's view of, and actions on, user accounts. */
interface UserAdminService {
    fun list(): List<UserDto>
    fun get(userId: Long): UserDto
    fun verify(userId: Long): UserDto
}

@Service
class UserAdminServiceImpl(private val users: UserRepository) : UserAdminService {

    override fun list(): List<UserDto> = users.findAll().map(UserDto::of)

    override fun get(userId: Long): UserDto =
        UserDto.of(users.findById(userId).orElseThrow { NotFoundException("User not found") })

    override fun verify(userId: Long): UserDto {
        val u = users.findById(userId).orElseThrow()
        u.isVerified = true
        return UserDto.of(users.save(u))
    }
}
