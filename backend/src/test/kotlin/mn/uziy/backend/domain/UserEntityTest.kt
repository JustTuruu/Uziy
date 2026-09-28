package mn.uziy.backend.domain

import org.junit.jupiter.api.Test
import java.time.LocalDate
import kotlin.test.assertEquals
import kotlin.test.assertNull

class UserEntityTest {

    @Test
    fun `age returns null when birthDate is null`() {
        val u = UserEntity(phoneNumber = "88112233", passwordHash = "x", role = Role.COMPANY)
        assertNull(u.age)
    }

    @Test
    fun `age computes years since birthDate for a birthday already passed this year`() {
        val today = LocalDate.now()
        val bd = today.minusYears(30).minusDays(30) // birthday was 30 days ago
        val u = UserEntity(phoneNumber = "1", passwordHash = "x", role = Role.VIEWER, birthDate = bd)
        assertEquals(30, u.age)
    }

    @Test
    fun `age subtracts one when birthday not yet reached this year`() {
        val today = LocalDate.now()
        val bd = today.minusYears(30).plusDays(30) // birthday hasn't arrived yet
        val u = UserEntity(phoneNumber = "1", passwordHash = "x", role = Role.VIEWER, birthDate = bd)
        assertEquals(29, u.age)
    }

    @Test
    fun `age is exactly N on the birthday itself`() {
        val today = LocalDate.now()
        val bd = today.minusYears(25)
        val u = UserEntity(phoneNumber = "1", passwordHash = "x", role = Role.VIEWER, birthDate = bd)
        assertEquals(25, u.age)
    }
}
