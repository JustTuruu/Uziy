package mn.uziy.backend.domain

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface UserRepository : JpaRepository<UserEntity, Long> {
    fun findByPhoneNumber(phoneNumber: String): UserEntity?
    fun existsByPhoneNumber(phoneNumber: String): Boolean
}
