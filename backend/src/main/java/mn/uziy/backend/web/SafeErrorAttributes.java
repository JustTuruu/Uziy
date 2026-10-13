package mn.uziy.backend.web;

import jakarta.servlet.RequestDispatcher;
import java.util.Map;
import org.springframework.boot.webmvc.error.DefaultErrorAttributes;
import org.springframework.boot.web.error.ErrorAttributeOptions;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.WebRequest;

/**
 * Keeps server-side detail out of error responses. 4xx messages are the application's own words for the
 * client ("Insufficient balance", "Код буруу…") and stay; a 5xx can carry anything — a SQL fragment, a class
 * name, a path — so its message is replaced with a fixed sentence, unless {@link ApiExceptionHandler} marked it
 * as a domain message ({@link #OWN_MESSAGE}, e.g. a 503 "provider unavailable" written for the user). The real
 * cause is in the server log.
 * Stack traces and exception names are removed from every error.
 */
@Component
public class SafeErrorAttributes extends DefaultErrorAttributes {

    static final String SERVER_ERROR_MESSAGE = "Internal server error";
    /** Request attribute: the error message is the application's own wording for the client. */
    static final String OWN_MESSAGE = SafeErrorAttributes.class.getName() + ".OWN_MESSAGE";

    @Override
    public Map<String, Object> getErrorAttributes(WebRequest request, ErrorAttributeOptions options) {
        Map<String, Object> attributes = super.getErrorAttributes(request, options);
        // Never a stack trace or an exception class name, whatever the status or the configuration: devtools
        // (present on a developer machine) switches traces on by default, and a trace maps out the code.
        attributes.remove("trace");
        attributes.remove("exception");
        // Read the status from the request itself, not from the attribute map: which keys the default
        // attributes include depends on the options and the Boot version.
        Object status = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE, RequestAttributes.SCOPE_REQUEST);
        boolean ownMessage = Boolean.TRUE.equals(request.getAttribute(OWN_MESSAGE, RequestAttributes.SCOPE_REQUEST));
        if (status instanceof Integer code && code >= 500 && !ownMessage) {
            attributes.put("message", SERVER_ERROR_MESSAGE);
        }
        return attributes;
    }
}
