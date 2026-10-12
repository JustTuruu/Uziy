package mn.uziy.backend.web;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.web.error.ErrorAttributeOptions;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.ServletWebRequest;

class SafeErrorAttributesTest {

    private final SafeErrorAttributes attributes = new SafeErrorAttributes();

    private java.util.Map<String, Object> forStatus(int status, String message) {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/x");
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
        assertThat(forStatus(400, "Insufficient balance")).containsEntry("message", "Insufficient balance");
    }

    @Test
    void aServerErrorNeverShowsItsInternals() {
        var attrs = forStatus(500, "could not execute statement [insert into secret_table]");

        assertThat(attrs).containsEntry("message", SafeErrorAttributes.SERVER_ERROR_MESSAGE);
        assertThat(attrs).doesNotContainKeys("trace", "exception");
        assertThat(attrs.toString()).doesNotContain("secret_table");
    }
}
