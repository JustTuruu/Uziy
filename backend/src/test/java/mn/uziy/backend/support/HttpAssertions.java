package mn.uziy.backend.support;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.uziy.backend.common.DomainException;
import mn.uziy.backend.web.ApiExceptionHandler;
import org.jspecify.annotations.Nullable;
import org.springframework.http.HttpStatus;

/** What a client would see for a {@link DomainException}, via the real mapping. */
public final class HttpAssertions {

    private HttpAssertions() {
    }

    /** Status and reason of a failure as the web layer would report it. */
    public record HttpFailure(HttpStatus statusCode, @Nullable String reason) {
    }

    /** Asserts {@code block} throws a {@link DomainException} and reports it the way the web layer would. */
    public static HttpFailure assertFailsWithHttp(Runnable block) {
        DomainException[] caught = new DomainException[1];
        assertThatThrownBy(block::run)
                .isInstanceOf(DomainException.class)
                .satisfies(t -> caught[0] = (DomainException) t);
        return new HttpFailure(ApiExceptionHandler.statusOf(caught[0]), caught[0].getMessage());
    }
}
