package mn.uziy.backend.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.DomainException;
import mn.uziy.backend.common.ForbiddenException;
import mn.uziy.backend.common.Messages;
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
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * The single place where exceptions become HTTP responses with words for the user.
 *
 * <p>Uses {@code sendError(status, message)} — exactly what Spring does for a
 * {@code ResponseStatusException} — so the JSON error body ({@code message} field, shown
 * because {@code server.error.include-message=always}) is unchanged for clients. Every message sent from here is
 * marked as ours ({@link SafeErrorAttributes#OWN_MESSAGE}); anything else Spring answers with gets a generic
 * Mongolian sentence from {@link SafeErrorAttributes}.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(ApiExceptionHandler.class);

    static final String INVALID_DATA = "Оруулсан мэдээлэл буруу байна. Шалгаад дахин оролдоно уу";
    static final String MALFORMED_BODY = "Илгээсэн мэдээлэл буруу хэлбэртэй байна. Дахин оролдоно уу";
    static final String BUSY = Messages.BUSY;

    @ExceptionHandler(DomainException.class)
    public void handle(DomainException e, HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        send(request, response, statusOf(e), e.getMessage());
    }

    /**
     * A request field broke its constraint: answer with that field's own message (see FieldMessages), never with
     * Spring's "Validation failed for object…" summary or the rejected value — which could be a password.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public void handleInvalidField(MethodArgumentNotValidException e, HttpServletRequest request,
                                  HttpServletResponse response) throws IOException {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .filter(m -> m != null && !m.isBlank())
                .findFirst()
                .orElse(INVALID_DATA);
        send(request, response, HttpStatus.BAD_REQUEST, message);
    }

    /**
     * A write the database refused (too long, duplicate, missing parent). Validation is meant to catch these
     * earlier; if one slips through it is the caller's data, not a server fault, so answer 400 without echoing
     * the SQL.
     */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public void handleIntegrity(DataIntegrityViolationException e, HttpServletRequest request,
                                HttpServletResponse response) throws IOException {
        LOG.warn("data integrity violation: {}", e.getMostSpecificCause().getMessage());
        send(request, response, HttpStatus.BAD_REQUEST, INVALID_DATA);
    }

    /** A body that is not the JSON the endpoint expects: say so, without echoing the parser's internals. */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public void handleUnreadable(HttpMessageNotReadableException e, HttpServletRequest request,
                                 HttpServletResponse response) throws IOException {
        send(request, response, HttpStatus.BAD_REQUEST, MALFORMED_BODY);
    }

    /** Two transactions raced and the database aborted one (see RetryingRewardService): ask the client to retry. */
    @ExceptionHandler(ConcurrencyFailureException.class)
    public void handleConcurrency(ConcurrencyFailureException e, HttpServletRequest request,
                                  HttpServletResponse response) throws IOException {
        LOG.info("concurrency failure: {}", e.getMessage());
        send(request, response, HttpStatus.CONFLICT, BUSY);
    }

    private static void send(HttpServletRequest request, HttpServletResponse response, HttpStatus status,
                             String message) throws IOException {
        request.setAttribute(SafeErrorAttributes.OWN_MESSAGE, Boolean.TRUE);
        response.sendError(status.value(), message);
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
