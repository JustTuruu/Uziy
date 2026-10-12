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

    @Test
    void aRequestWithoutABodyPasses() throws Exception {
        FilterChain[] chain = new FilterChain[1];

        assertThat(run(0, chain).getStatus()).isEqualTo(200);
    }
}
