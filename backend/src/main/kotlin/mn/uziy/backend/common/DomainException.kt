package mn.uziy.backend.common

/**
 * Business-rule failures raised by the service layer. They carry no HTTP
 * vocabulary — the web layer ([mn.uziy.backend.web.ApiExceptionHandler])
 * decides which status each one maps to, so services stay usable (and
 * testable) without Spring MVC.
 */
sealed class DomainException(message: String? = null) : RuntimeException(message)

/** The thing asked for does not exist → 404. */
class NotFoundException(message: String? = null) : DomainException(message)

/** The thing exists but belongs to someone else → 403. */
class ForbiddenException(message: String? = null) : DomainException(message)

/** The request itself is invalid → 400. */
class BadRequestException(message: String? = null) : DomainException(message)

/** The request is valid but clashes with current state → 409. */
class ConflictException(message: String? = null) : DomainException(message)

/** Credentials were not accepted → 401. */
class UnauthorizedException(message: String? = null) : DomainException(message)

/** A required collaborator (e.g. a payment gateway) is not available → 503. */
class UnavailableException(message: String? = null) : DomainException(message)
