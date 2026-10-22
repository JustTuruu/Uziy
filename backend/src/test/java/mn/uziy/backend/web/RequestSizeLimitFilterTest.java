package mn.uziy.backend.web;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RequestSizeLimitFilterTest {

    private final RequestSizeLimitFilter filter = new RequestSizeLimitFilter();

    private MockHttpServletResponse run(int contentLength, FilterChain[] chainOut) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/auth/login");
        request.setContent(new byte[contentLength]);
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(request, response, chain);
        chainOut[0] = chain;
        return response;
    }

    @Test
    void aBodyAtTheLimitPassesThrough() throws Exception {
        FilterChain[] chain = new FilterChain[1];

        MockHttpServletResponse response = run((int) RequestSizeLimitFilter.MAX_BODY_BYTES, chain);

        assertThat(response.getStatus()).isEqualTo(200);
        assertThat(((MockFilterChain) chain[0]).getRequest()).isNotNull();
    }

    @Test
    void aBodyOverTheLimitIsTurnedAwayBeforeTheApplicationSeesIt() throws Exception {
        FilterChain[] chain = new FilterChain[1];

        MockHttpServletResponse response = run((int) RequestSizeLimitFilter.MAX_BODY_BYTES + 1, chain);

        assertThat(response.getStatus()).isEqualTo(413);
        assertThat(((MockFilterChain) chain[0]).getRequest()).isNull();
    }

    /** Regression (audit 2026-10-22): a real cover photo (hundreds of KB) was refused with 413. */
    @Test
    void aMultipartImageUploadMayBeLargerUpToTheUploadLimit() throws Exception {
        MockHttpServletRequest photo = new MockHttpServletRequest("POST", "/company/campaigns/1/image");
        photo.setContentType("multipart/form-data; boundary=x");
        photo.setContent(new byte[2 * 1024 * 1024]);
        MockHttpServletResponse ok = new MockHttpServletResponse();
        filter.doFilter(photo, ok, new MockFilterChain());
        assertThat(ok.getStatus()).isEqualTo(200);

        MockHttpServletRequest huge = new MockHttpServletRequest("POST", "/company/campaigns/1/image");
        huge.setContentType("multipart/form-data; boundary=x");
        huge.setContent(new byte[(int) RequestSizeLimitFilter.MAX_MULTIPART_BYTES + 1]);
        MockHttpServletResponse tooBig = new MockHttpServletResponse();
        filter.doFilter(huge, tooBig, new MockFilterChain());
        assertThat(tooBig.getStatus()).isEqualTo(413);
    }

    @Test
    void aRequestWithoutABodyPasses() throws Exception {
        FilterChain[] chain = new FilterChain[1];

        assertThat(run(0, chain).getStatus()).isEqualTo(200);
    }
}
