package mn.uziy.backend.web;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.DomainException;
import mn.uziy.backend.common.ForbiddenException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.common.UnavailableException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * The single place where {@link DomainException}s become HTTP responses.
 *
 * <p>Uses {@code sendError(status, message)} — exactly what Spring does for a
 * {@code ResponseStatusException} — so the JSON error body ({@code message} field, shown
 * because {@code server.error.include-message=always}) is unchanged for clients.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(DomainException.class)
    public void handle(DomainException e, HttpServletResponse response) throws IOException {
        response.sendError(statusOf(e).value(), e.getMessage());
    }

    public static HttpStatus statusOf(DomainException e) {
        if (e instanceof NotFoundException) return HttpStatus.NOT_FOUND;
        if (e instanceof ForbiddenException) return HttpStatus.FORBIDDEN;
        if (e instanceof BadRequestException) return HttpStatus.BAD_REQUEST;
        if (e instanceof ConflictException) return HttpStatus.CONFLICT;
        if (e instanceof UnauthorizedException) return HttpStatus.UNAUTHORIZED;
        if (e instanceof UnavailableException) return HttpStatus.SERVICE_UNAVAILABLE;
        if (e instanceof TooManyRequestsException) return HttpStatus.TOO_MANY_REQUESTS;
        throw new IllegalStateException("Unmapped domain exception: " + e.getClass());
    }
}
