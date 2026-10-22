package mn.uziy.backend.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Turns away an oversized request body before it is read. Every body this API takes is small JSON (a login,
 * a campaign with its questions), so a body of hundreds of kilobytes is an attack on memory, not a request.
 * Judged by the declared Content-Length; a body sent in chunks without one is still bounded by the
 * server's own limits.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestSizeLimitFilter extends OncePerRequestFilter {

    public static final long MAX_BODY_BYTES = 256 * 1024;

    /**
     * A multipart body (a cover image) may be as large as {@code spring.servlet.multipart.max-request-size}
     * (6 MB): the image itself is capped at 5 MB by the media service. With the JSON limit every real photo was
     * refused (audit 2026-10-22).
     */
    public static final long MAX_MULTIPART_BYTES = 6L * 1024 * 1024;

    private static final String MULTIPART = "multipart/";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        if (request.getContentLengthLong() > limitFor(request)) {
            // No message: SafeErrorAttributes words every 413 for the user.
            response.sendError(HttpStatus.CONTENT_TOO_LARGE.value());
            return;
        }
        chain.doFilter(request, response);
    }

    static long limitFor(HttpServletRequest request) {
        String type = request.getContentType();
        return type != null && type.toLowerCase(java.util.Locale.ROOT).startsWith(MULTIPART)
                ? MAX_MULTIPART_BYTES
                : MAX_BODY_BYTES;
    }
}
