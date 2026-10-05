package mn.uziy.backend.web

import jakarta.servlet.http.HttpServletResponse
import mn.uziy.backend.common.*
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice

/**
 * The single place where [DomainException]s become HTTP responses.
 *
 * Uses `sendError(status, message)` — exactly what Spring does for a
 * `ResponseStatusException` — so the JSON error body (`message` field, shown
 * because `server.error.include-message=always`) is unchanged for clients.
 */
@RestControllerAdvice
class ApiExceptionHandler {

    @ExceptionHandler(DomainException::class)
    fun handle(e: DomainException, response: HttpServletResponse) {
        response.sendError(statusOf(e).value(), e.message)
    }

    companion object {
        fun statusOf(e: DomainException): HttpStatus = when (e) {
            is NotFoundException -> HttpStatus.NOT_FOUND
            is ForbiddenException -> HttpStatus.FORBIDDEN
            is BadRequestException -> HttpStatus.BAD_REQUEST
            is ConflictException -> HttpStatus.CONFLICT
            is UnauthorizedException -> HttpStatus.UNAUTHORIZED
            is UnavailableException -> HttpStatus.SERVICE_UNAVAILABLE
        }
    }
}
