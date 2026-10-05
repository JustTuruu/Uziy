package mn.uziy.backend.support

import mn.uziy.backend.common.DomainException
import mn.uziy.backend.web.ApiExceptionHandler
import org.springframework.http.HttpStatus
import kotlin.test.assertFailsWith

/** What a client would see for a [DomainException], via the real mapping. */
class HttpFailure(val statusCode: HttpStatus, val reason: String?)

/** Asserts [block] throws a [DomainException] and reports it the way the web layer would. */
fun assertFailsWithHttp(block: () -> Unit): HttpFailure {
    val e = assertFailsWith<DomainException> { block() }
    return HttpFailure(ApiExceptionHandler.statusOf(e), e.message)
}
