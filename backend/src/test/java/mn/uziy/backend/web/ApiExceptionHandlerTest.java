package mn.uziy.backend.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import java.util.Map;
import java.util.stream.Stream;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.DomainException;
import mn.uziy.backend.common.ForbiddenException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.common.UnavailableException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

class ApiExceptionHandlerTest {

    @RestController
    static class Boom {
        @GetMapping("/boom/not-found")
        void a() { throw new NotFoundException("nf"); }

        @GetMapping("/boom/forbidden")
        void b() { throw new ForbiddenException("fb"); }

        @GetMapping("/boom/bad-request")
        void c() { throw new BadRequestException("br"); }

        @GetMapping("/boom/conflict")
        void d() { throw new ConflictException("cf"); }

        @GetMapping("/boom/unauthorized")
        void e() { throw new UnauthorizedException("un"); }

        @GetMapping("/boom/unavailable")
        void f() { throw new UnavailableException("uv"); }
    }

    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new Boom())
            .setControllerAdvice(new ApiExceptionHandler())
            .build();

    static Stream<Arguments> cases() {
        return Stream.of(
                Arguments.of(new NotFoundException("x"), HttpStatus.NOT_FOUND),
                Arguments.of(new ForbiddenException("x"), HttpStatus.FORBIDDEN),
                Arguments.of(new BadRequestException("x"), HttpStatus.BAD_REQUEST),
                Arguments.of(new ConflictException("x"), HttpStatus.CONFLICT),
                Arguments.of(new UnauthorizedException("x"), HttpStatus.UNAUTHORIZED),
                Arguments.of(new UnavailableException("x"), HttpStatus.SERVICE_UNAVAILABLE));
    }

    @ParameterizedTest
    @MethodSource("cases")
    void eachDomainExceptionMapsToItsHttpStatus(DomainException e, HttpStatus expected) {
        assertThat(ApiExceptionHandler.statusOf(e)).isEqualTo(expected);
    }

    @Test
    void theResponseCarriesTheStatusAndTheMessageAsTheErrorReason() throws Exception {
        var res = mvc.perform(get("/boom/conflict")).andReturn().getResponse();
        assertThat(res.getStatus()).isEqualTo(409);
        assertThat(res.getErrorMessage()).isEqualTo("cf");
    }

    @Test
    void everyRouteThroughTheAdviceAnswersWithItsMappedStatus() throws Exception {
        Map<String, Integer> expected = Map.of(
                "not-found", 404, "forbidden", 403, "bad-request", 400,
                "conflict", 409, "unauthorized", 401, "unavailable", 503);
        for (var entry : expected.entrySet()) {
            int status = mvc.perform(get("/boom/" + entry.getKey())).andReturn().getResponse().getStatus();
            assertThat(status).as(entry.getKey()).isEqualTo(entry.getValue());
        }
    }
}
