package mn.zoos.backend.payout

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import mn.zoos.backend.domain.*
import mn.zoos.backend.security.JwtPrincipal
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class PayoutControllerTest {

    private val payouts = mockk<PayoutRepository>()
    private val users = mockk<UserRepository>()
    private val controller = PayoutController(payouts, users)

    private val viewer = UserEntity(
        id = 42L, phoneNumber = "77000001", passwordHash = "x",
        role = Role.VIEWER, balance = 1500.0, isVerified = false,
    )
    private val admin = UserEntity(
        id = 1L, phoneNumber = "99990000", passwordHash = "x", role = Role.ADMIN,
    )

    private val viewerPrincipal = JwtPrincipal(userId = 42L, role = Role.VIEWER)
    private val adminPrincipal = JwtPrincipal(userId = 1L, role = Role.ADMIN)

    private fun reqBody(amount: Double = 500.0) = CreatePayoutReq(
        amount = amount, bank = "Khan Bank",
        accountNumber = "5001234567", accountName = "БОЛД ЭРДЭНЭ",
        nationalId = "УУ98761234",
    )

    // ------- viewer.request ------------------------------------------------

    @Test
    fun `request reserves balance and marks first payout`() {
        val u = viewer
        every { users.findById(42L) } returns Optional.of(u)
        every { payouts.existsByUserIdAndStatus(42L, PayoutStatus.APPROVED) } returns false
        val savedUser = slot<UserEntity>()
        every { users.save(capture(savedUser)) } answers { savedUser.captured }
        val savedPayout = slot<PayoutEntity>()
        every { payouts.save(capture(savedPayout)) } answers {
            savedPayout.captured.also { it.id = 1L }
        }

        val dto = controller.request(reqBody(500.0), viewerPrincipal)

        assertEquals(1L, dto.id)
        assertTrue(dto.isFirstPayout)
        assertEquals(PayoutStatus.PENDING, dto.status)
        assertEquals(1000.0, savedUser.captured.balance) // 1500 − 500
    }

    @Test
    fun `request throws 400 on insufficient balance`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        val ex = assertFailsWith<ResponseStatusException> {
            controller.request(reqBody(amount = 9999.0), viewerPrincipal)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
        verify(exactly = 0) { payouts.save(any()) }
    }

    @Test
    fun `request marks isFirstPayout=false when user has a prior APPROVED payout`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        every { payouts.existsByUserIdAndStatus(42L, PayoutStatus.APPROVED) } returns true
        every { users.save(any()) } answers { firstArg() }
        val savedPayout = slot<PayoutEntity>()
        every { payouts.save(capture(savedPayout)) } answers {
            savedPayout.captured.also { it.id = 2L }
        }

        val dto = controller.request(reqBody(500.0), viewerPrincipal)
        assertEquals(false, dto.isFirstPayout)
    }

    // ------- viewer.mine ---------------------------------------------------

    @Test
    fun `mine returns own payouts newest first`() {
        every { users.findById(42L) } returns Optional.of(viewer)
        every { payouts.findAllByUserIdOrderByRequestedAtDesc(42L) } returns listOf(
            PayoutEntity(id = 1L, userId = 42L, amount = 500.0,
                bank = "Khan", accountNumber = "1", accountName = "X",
                nationalId = "Y", status = PayoutStatus.PENDING),
        )
        val list = controller.mine(viewerPrincipal)
        assertEquals(1, list.size)
        assertEquals(PayoutStatus.PENDING, list[0].status)
    }

    // ------- admin.pending -------------------------------------------------

    @Test
    fun `admin pending list is enriched with user phone numbers`() {
        every { payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING) } returns
                listOf(
                    PayoutEntity(id = 10L, userId = 42L, amount = 500.0,
                        bank = "Khan", accountNumber = "1", accountName = "X",
                        nationalId = "Y", status = PayoutStatus.PENDING),
                )
        every { users.findAllById(listOf(42L)) } returns listOf(viewer)

        val list = controller.pending()
        assertEquals(1, list.size)
        assertEquals("77000001", list[0].userPhone)
    }

    // ------- admin.decide --------------------------------------------------

    @Test
    fun `decide APPROVED on first payout flips is_verified to TRUE (spec 4A)`() {
        val p = PayoutEntity(
            id = 10L, userId = 42L, amount = 500.0, bank = "Khan",
            accountNumber = "1", accountName = "X", nationalId = "Y",
            status = PayoutStatus.PENDING, isFirstPayout = true,
        )
        every { payouts.findById(10L) } returns Optional.of(p)
        every { users.findById(42L) } returns Optional.of(viewer.apply { isVerified = false })
        val savedUser = slot<UserEntity>()
        every { users.save(capture(savedUser)) } answers { savedUser.captured }
        val savedPayout = slot<PayoutEntity>()
        every { payouts.save(capture(savedPayout)) } answers { savedPayout.captured }

        controller.decide(10L, PayoutStatus.APPROVED, null, adminPrincipal)

        assertTrue(savedUser.captured.isVerified)
        assertEquals(PayoutStatus.APPROVED, savedPayout.captured.status)
        assertEquals(1L, savedPayout.captured.decidedBy)
        assertNotNull(savedPayout.captured.decidedAt)
    }

    @Test
    fun `decide APPROVED on repeat payout keeps is_verified as it was`() {
        val p = PayoutEntity(
            id = 11L, userId = 42L, amount = 500.0, bank = "Khan",
            accountNumber = "1", accountName = "X", nationalId = "Y",
            status = PayoutStatus.PENDING, isFirstPayout = false,
        )
        every { payouts.findById(11L) } returns Optional.of(p)
        val existing = viewer.apply { isVerified = false; balance = 1000.0 }
        every { users.findById(42L) } returns Optional.of(existing)
        val savedUser = slot<UserEntity>()
        every { users.save(capture(savedUser)) } answers { savedUser.captured }
        every { payouts.save(any()) } answers { firstArg() }

        controller.decide(11L, PayoutStatus.APPROVED, null, adminPrincipal)

        // Balance untouched; is_verified NOT flipped because isFirstPayout=false.
        assertEquals(1000.0, savedUser.captured.balance)
        assertEquals(false, savedUser.captured.isVerified)
    }

    @Test
    fun `decide REJECTED refunds reserved balance`() {
        val p = PayoutEntity(
            id = 12L, userId = 42L, amount = 500.0, bank = "Khan",
            accountNumber = "1", accountName = "X", nationalId = "Y",
            status = PayoutStatus.PENDING, isFirstPayout = true,
        )
        every { payouts.findById(12L) } returns Optional.of(p)
        val reservedUser = viewer.apply { balance = 200.0 } // 700 minus 500 reserved
        every { users.findById(42L) } returns Optional.of(reservedUser)
        val savedUser = slot<UserEntity>()
        every { users.save(capture(savedUser)) } answers { savedUser.captured }
        every { payouts.save(any()) } answers { firstArg() }

        controller.decide(12L, PayoutStatus.REJECTED, "wrong name", adminPrincipal)

        assertEquals(700.0, savedUser.captured.balance) // refunded
    }

    @Test
    fun `decide throws 400 when target status is PENDING`() {
        val ex = assertFailsWith<ResponseStatusException> {
            controller.decide(1L, PayoutStatus.PENDING, null, adminPrincipal)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }

    @Test
    fun `decide throws 409 when the payout was already decided`() {
        val already = PayoutEntity(
            id = 13L, userId = 42L, amount = 500.0, bank = "Khan",
            accountNumber = "1", accountName = "X", nationalId = "Y",
            status = PayoutStatus.APPROVED,
        )
        every { payouts.findById(13L) } returns Optional.of(already)

        val ex = assertFailsWith<ResponseStatusException> {
            controller.decide(13L, PayoutStatus.REJECTED, null, adminPrincipal)
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
    }
}
