package mn.uziy.backend.web;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.web.error.ErrorAttributeOptions;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.ServletWebRequest;

class SafeErrorAttributesTest {

    private final SafeErrorAttributes attributes = new SafeErrorAttributes();

    private java.util.Map<String, Object> forStatus(int status, String message) {
        return forStatus(status, message, false);
    }

    private java.util.Map<String, Object> forStatus(int status, String message, boolean ownMessage) {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/x");
        if (ownMessage) {
            request.setAttribute(SafeErrorAttributes.OWN_MESSAGE, Boolean.TRUE);
        }
        request.setAttribute("jakarta.servlet.error.status_code", status);
        request.setAttribute("jakarta.servlet.error.message", message);
        request.setAttribute("jakarta.servlet.error.exception",
                new IllegalStateException("could not execute statement [insert into secret_table]"));
        return attributes.getErrorAttributes(new ServletWebRequest(request),
                ErrorAttributeOptions.of(ErrorAttributeOptions.Include.MESSAGE, ErrorAttributeOptions.Include.EXCEPTION,
                        ErrorAttributeOptions.Include.STACK_TRACE));
    }

    @Test
    void noErrorEverCarriesAStackTraceOrExceptionClass() {
        for (int status : new int[] {400, 401, 404, 409, 500}) {
            assertThat(forStatus(status, "m")).as("status %d", status).doesNotContainKeys("trace", "exception");
        }
    }

    @Test
    void aClientErrorKeepsTheApplicationsOwnWords() {
        assertThat(forStatus(400, "Хэтэвчний үлдэгдэл хүрэлцэхгүй байна", true))
                .containsEntry("message", "Хэтэвчний үлдэгдэл хүрэлцэхгүй байна");
    }

    /** Regression (2026-10-13): Spring's own English/technical text reached the app ("Forbidden", UUID errors). */
    @Test
    void anErrorTheApplicationDidNotWordGetsAMongolianSentenceForItsStatus() {
        assertThat(forStatus(400, "Failed to convert value of type 'java.lang.String' to required type 'UUID'"))
                .containsEntry("message", SafeErrorAttributes.BAD_REQUEST_MESSAGE);
        assertThat(forStatus(401, "Unauthorized")).containsEntry("message", SafeErrorAttributes.UNAUTHORIZED_MESSAGE);
        assertThat(forStatus(403, "Forbidden")).containsEntry("message", SafeErrorAttributes.FORBIDDEN_MESSAGE);
        assertThat(forStatus(404, "No static resource x")).containsEntry("message", SafeErrorAttributes.NOT_FOUND_MESSAGE);
        assertThat(forStatus(405, "Method not allowed")).containsEntry("message", SafeErrorAttributes.CLIENT_ERROR_MESSAGE);
        assertThat(forStatus(413, "")).containsEntry("message", SafeErrorAttributes.TOO_LARGE_MESSAGE);
        assertThat(forStatus(429, "")).containsEntry("message", SafeErrorAttributes.TOO_MANY_MESSAGE);
        assertThat(forStatus(502, "")).containsEntry("message", SafeErrorAttributes.SERVER_ERROR_MESSAGE);
    }

    @Test
    void theFieldErrorListIsNeverSentBecauseItEchoesTheRejectedValue() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/auth/login");
        request.setAttribute("jakarta.servlet.error.status_code", 400);
        var bindingResult = new org.springframework.validation.BeanPropertyBindingResult(new Object(), "loginReq");
        bindingResult.addError(new org.springframework.validation.FieldError(
                "loginReq", "password", "my-secret-password", false, null, null, "bad"));
        request.setAttribute(org.springframework.boot.webmvc.error.DefaultErrorAttributes.class.getName() + ".ERROR",
                new org.springframework.validation.BindException(bindingResult));

        var attrs = attributes.getErrorAttributes(new ServletWebRequest(request),
                ErrorAttributeOptions.of(ErrorAttributeOptions.Include.BINDING_ERRORS));

        assertThat(attrs).doesNotContainKey("errors");
        assertThat(attrs.toString()).doesNotContain("my-secret-password");
    }

    /** Regression (2026-10-13): Spring rebuilt the message from the BindingResult over our field message. */
    @Test
    void ourOwnMessageWinsOverSpringsValidationSummary() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/auth/login");
        request.setAttribute("jakarta.servlet.error.status_code", 400);
        request.setAttribute("jakarta.servlet.error.message", "Утасны дугаар 8 оронтой тоо байх ёстой");
        request.setAttribute(SafeErrorAttributes.OWN_MESSAGE, Boolean.TRUE);
        var bindingResult = new org.springframework.validation.BeanPropertyBindingResult(new Object(), "loginReq");
        bindingResult.addError(new org.springframework.validation.FieldError("loginReq", "phoneNumber", "bad"));
        request.setAttribute(org.springframework.boot.webmvc.error.DefaultErrorAttributes.class.getName() + ".ERROR",
                new org.springframework.validation.BindException(bindingResult));

        var attrs = attributes.getErrorAttributes(new ServletWebRequest(request),
                ErrorAttributeOptions.of(ErrorAttributeOptions.Include.MESSAGE));

        assertThat(attrs).containsEntry("message", "Утасны дугаар 8 оронтой тоо байх ёстой");
    }

    @Test
    void everyGenericSentenceIsMongolian() {
        for (int status : new int[] {400, 401, 403, 404, 405, 409, 413, 429, 500, 503}) {
            assertThat(SafeErrorAttributes.messageFor(status)).as("status %d", status).matches(".*[А-Яа-яӨөҮүЁё].*")
                    .doesNotContainPattern("[A-Za-z]");
        }
    }

    @Test
    void aServerErrorNeverShowsItsInternals() {
        var attrs = forStatus(500, "could not execute statement [insert into secret_table]");

        assertThat(attrs).containsEntry("message", SafeErrorAttributes.SERVER_ERROR_MESSAGE);
        assertThat(attrs).doesNotContainKeys("trace", "exception");
        assertThat(attrs.toString()).doesNotContain("secret_table");
    }

    /** Regression (2026-10-13): the phone-check 503 reached the app as an English "Internal server error". */
    @Test
    void aDomain503KeepsItsMessageForTheUser() {
        var attrs = forStatus(503, "Баталгаажуулалт эхлүүлж чадсангүй. Дахин оролдоно уу", true);

        assertThat(attrs).containsEntry("message", "Баталгаажуулалт эхлүүлж чадсангүй. Дахин оролдоно уу");
        assertThat(attrs).doesNotContainKeys("trace", "exception");
    }
}
