package mn.uziy.backend.web

import mn.uziy.backend.common.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.MethodSource
import org.springframework.http.HttpStatus
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.setup.MockMvcBuilders
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import java.util.stream.Stream
import kotlin.test.assertEquals

class ApiExceptionHandlerTest {

    @RestController
    class Boom {
        @GetMapping("/boom/not-found") fun a(): Unit = throw NotFoundException("nf")
        @GetMapping("/boom/forbidden") fun b(): Unit = throw ForbiddenException()
        @GetMapping("/boom/bad-request") fun c(): Unit = throw BadRequestException("br")
        @GetMapping("/boom/conflict") fun d(): Unit = throw ConflictException("cf")
        @GetMapping("/boom/unauthorized") fun e(): Unit = throw UnauthorizedException("un")
        @GetMapping("/boom/unavailable") fun f(): Unit = throw UnavailableException("uv")
    }

    private val mvc: MockMvc = MockMvcBuilders.standaloneSetup(Boom())
        .setControllerAdvice(ApiExceptionHandler())
        .build()

    companion object {
        @JvmStatic
        fun cases(): Stream<Arguments> = Stream.of(
            Arguments.of(NotFoundException("x"), HttpStatus.NOT_FOUND),
            Arguments.of(ForbiddenException("x"), HttpStatus.FORBIDDEN),
            Arguments.of(BadRequestException("x"), HttpStatus.BAD_REQUEST),
            Arguments.of(ConflictException("x"), HttpStatus.CONFLICT),
            Arguments.of(UnauthorizedException("x"), HttpStatus.UNAUTHORIZED),
            Arguments.of(UnavailableException("x"), HttpStatus.SERVICE_UNAVAILABLE),
        )
    }

    @ParameterizedTest
    @MethodSource("cases")
    fun `each domain exception maps to its HTTP status`(e: DomainException, expected: HttpStatus) {
        assertEquals(expected, ApiExceptionHandler.statusOf(e))
    }

    @Test
    fun `the response carries the status and the message as the error reason`() {
        val res = mvc.perform(get("/boom/conflict")).andReturn().response
        assertEquals(409, res.status)
        assertEquals("cf", res.errorMessage)
    }

    @Test
    fun `every route through the advice answers with its mapped status`() {
        val expected = mapOf(
            "not-found" to 404, "forbidden" to 403, "bad-request" to 400,
            "conflict" to 409, "unauthorized" to 401, "unavailable" to 503,
        )
        expected.forEach { (path, status) ->
            assertEquals(status, mvc.perform(get("/boom/$path")).andReturn().response.status, path)
        }
    }
}
