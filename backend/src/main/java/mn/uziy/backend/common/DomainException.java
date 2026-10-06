package mn.uziy.backend.common;

/**
 * Business-rule failures raised by the service layer. They carry no HTTP
 * vocabulary — the web layer ({@code mn.uziy.backend.web.ApiExceptionHandler})
 * decides which status each one maps to, so services stay usable (and
 * testable) without Spring MVC.
 */
public abstract sealed class DomainException extends RuntimeException
        permits NotFoundException, ForbiddenException, BadRequestException,
                ConflictException, UnauthorizedException, UnavailableException {

    protected DomainException(String message) {
        super(message);
    }
}
