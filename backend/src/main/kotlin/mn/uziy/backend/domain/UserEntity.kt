package mn.uziy.backend.domain

import jakarta.persistence.*
import java.time.LocalDate
import java.time.OffsetDateTime

enum class Role { VIEWER, COMPANY, ADMIN }
enum class Gender { MALE, FEMALE }

@Entity
@Table(name = "users")
class UserEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(name = "phone_number", nullable = false, unique = true, length = 15)
    var phoneNumber: String = "",

    @Column(name = "password_hash", nullable = false)
    var passwordHash: String = "",

    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    var role: Role = Role.VIEWER,

    @Enumerated(EnumType.STRING) @Column(length = 10)
    var gender: Gender? = null,

    @Column(name = "birth_date")
    var birthDate: LocalDate? = null,

    @Column(length = 50)
    var city: String? = null,

    @Column(length = 50)
    var district: String? = null,

    @Column(nullable = false)
    var balance: Double = 0.0,

    @Column(name = "is_verified", nullable = false)
    var isVerified: Boolean = false,

    @Column(name = "company_name", length = 120)
    var companyName: String? = null,

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now(),
) {
    /** Age computed from birth_date. Null for non-viewer accounts. */
    val age: Int?
        get() = birthDate?.let {
            val today = LocalDate.now()
            var years = today.year - it.year
            if (today.monthValue < it.monthValue ||
                (today.monthValue == it.monthValue && today.dayOfMonth < it.dayOfMonth)) years -= 1
            years
        }
}
