package mn.uziy.backend.web;

import jakarta.servlet.RequestDispatcher;
import java.util.Map;
import org.springframework.boot.web.error.ErrorAttributeOptions;
import org.springframework.boot.webmvc.error.DefaultErrorAttributes;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.WebRequest;

/**
 * Every error body ends with a message a user can read, and nothing internal.
 *
 * <p>A message {@link ApiExceptionHandler} marked as ours ({@link #OWN_MESSAGE}: domain failures and field
 * validation, already worded for the user) is kept, whatever the status. Anything else — Spring's own answers
 * ("Forbidden", "Failed to convert … to UUID", a 404 route, a 5xx that may carry SQL or class names) — is replaced
 * with a fixed Mongolian sentence for its status. Stack traces, exception names and the per-field {@code errors}
 * list (which echoes the rejected value, e.g. a password) are removed from every error. The real cause is in the
 * server log.
 */
@Component
public class SafeErrorAttributes extends DefaultErrorAttributes {

    /** Request attribute: the error message is the application's own wording for the client. */
    static final String OWN_MESSAGE = SafeErrorAttributes.class.getName() + ".OWN_MESSAGE";

    static final String SERVER_ERROR_MESSAGE = "Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу";
    static final String BAD_REQUEST_MESSAGE = "Оруулсан мэдээлэл буруу байна. Шалгаад дахин оролдоно уу";
    static final String UNAUTHORIZED_MESSAGE = "Нэвтрэх шаардлагатай. Дахин нэвтэрнэ үү";
    static final String FORBIDDEN_MESSAGE = "Танд энэ үйлдлийг хийх эрх байхгүй байна. Дахин нэвтэрнэ үү";
    static final String NOT_FOUND_MESSAGE = "Хайсан зүйл олдсонгүй";
    static final String TOO_LARGE_MESSAGE = "Илгээсэн мэдээлэл хэт том байна";
    static final String TOO_MANY_MESSAGE = "Хэт олон хүсэлт илгээлээ. Түр хүлээгээд дахин оролдоно уу";
    static final String CLIENT_ERROR_MESSAGE = "Хүсэлтийг биелүүлэх боломжгүй байна. Дахин оролдоно уу";

    @Override
    public Map<String, Object> getErrorAttributes(WebRequest request, ErrorAttributeOptions options) {
        Map<String, Object> attributes = super.getErrorAttributes(request, options);
        // Never a stack trace or an exception class name, whatever the status or the configuration: devtools
        // (present on a developer machine) switches traces on by default, and a trace maps out the code.
        attributes.remove("trace");
        attributes.remove("exception");
        attributes.remove("errors");
        // Read the status from the request itself, not from the attribute map: which keys the default
        // attributes include depends on the options and the Boot version.
        Object status = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE, RequestAttributes.SCOPE_REQUEST);
        boolean ownMessage = Boolean.TRUE.equals(request.getAttribute(OWN_MESSAGE, RequestAttributes.SCOPE_REQUEST));
        if (ownMessage) {
            // Exactly what we passed to sendError: Spring would otherwise rebuild a validation failure's message
            // from its BindingResult ("Validation failed for object='loginReq'…").
            Object sent = request.getAttribute(RequestDispatcher.ERROR_MESSAGE, RequestAttributes.SCOPE_REQUEST);
            if (sent instanceof String text && !text.isBlank()) {
                attributes.put("message", text);
            }
        } else if (status instanceof Integer code) {
            attributes.put("message", messageFor(code));
        }
        return attributes;
    }

    /** The generic sentence for an error the application did not word itself. */
    static String messageFor(int status) {
        if (status >= 500) return SERVER_ERROR_MESSAGE;
        return switch (status) {
            case 400 -> BAD_REQUEST_MESSAGE;
            case 401 -> UNAUTHORIZED_MESSAGE;
            case 403 -> FORBIDDEN_MESSAGE;
            case 404 -> NOT_FOUND_MESSAGE;
            case 413 -> TOO_LARGE_MESSAGE;
            case 429 -> TOO_MANY_MESSAGE;
            default -> CLIENT_ERROR_MESSAGE;
        };
    }
}
