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

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        if (request.getContentLengthLong() > MAX_BODY_BYTES) {
            response.sendError(HttpStatus.CONTENT_TOO_LARGE.value(), "Request too large");
            return;
        }
        chain.doFilter(request, response);
    }
}
