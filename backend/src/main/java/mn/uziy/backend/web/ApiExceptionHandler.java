package mn.uziy.backend.web;

import jakarta.servlet.http.HttpServletRequest;
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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
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

    private static final Logger LOG = LoggerFactory.getLogger(ApiExceptionHandler.class);

    static final String INVALID_DATA = "Invalid data";
    static final String MALFORMED_BODY = "Malformed request body";
    static final String BUSY = "Busy, please try again";

    /** A domain message is always our own words for the client, so it is shown even on a 503. */
    @ExceptionHandler(DomainException.class)
    public void handle(DomainException e, HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        request.setAttribute(SafeErrorAttributes.OWN_MESSAGE, Boolean.TRUE);
        response.sendError(statusOf(e).value(), e.getMessage());
    }

    /**
     * A write the database refused (too long, duplicate, missing parent). Validation is meant to catch these
     * earlier; if one slips through it is the caller's data, not a server fault, so answer 400 without echoing
     * the SQL.
     */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public void handleIntegrity(DataIntegrityViolationException e, HttpServletResponse response)
            throws IOException {
        LOG.warn("data integrity violation: {}", e.getMostSpecificCause().getMessage());
        response.sendError(HttpStatus.BAD_REQUEST.value(), INVALID_DATA);
    }

    /** A body that is not the JSON the endpoint expects: say so, without echoing the parser's internals. */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public void handleUnreadable(HttpMessageNotReadableException e, HttpServletResponse response) throws IOException {
        response.sendError(HttpStatus.BAD_REQUEST.value(), MALFORMED_BODY);
    }

    /** Two transactions raced and the database aborted one (see RetryingRewardService): ask the client to retry. */
    @ExceptionHandler(ConcurrencyFailureException.class)
    public void handleConcurrency(ConcurrencyFailureException e, HttpServletResponse response) throws IOException {
        LOG.info("concurrency failure: {}", e.getMessage());
        response.sendError(HttpStatus.CONFLICT.value(), BUSY);
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
