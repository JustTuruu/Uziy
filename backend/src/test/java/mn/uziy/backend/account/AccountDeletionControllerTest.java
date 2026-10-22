package mn.uziy.backend.account;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import mn.uziy.backend.domain.Role;
import mn.uziy.backend.security.AuthArgumentResolver;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/** HTTP contract of {@code DELETE /viewer/me}: 204, the caller's id, and the password is required. */
class AccountDeletionControllerTest {

    private final AccountDeletionService deletion = mock(AccountDeletionService.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new AccountDeletionController(deletion))
            .setCustomArgumentResolvers(new AuthArgumentResolver())
            .build();

    @BeforeEach
    void authenticate() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtPrincipal(42L, Role.VIEWER), null));
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void deletesTheCallersOwnAccountAndAnswers204() throws Exception {
        mvc.perform(delete("/viewer/me").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"password\":\"secret12\"}"))
                .andExpect(status().isNoContent());

        verify(deletion).deleteOwnAccount(42L, "secret12");
    }

    @Test
    void aMissingPasswordIs400AndDeletesNothing() throws Exception {
        mvc.perform(delete("/viewer/me").contentType(MediaType.APPLICATION_JSON).content("{\"password\":\" \"}"))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(deletion);
    }

    @Test
    void onlyViewersMayCallIt() {
        assertThat(AccountDeletionController.class.getAnnotation(PreAuthorize.class).value())
                .isEqualTo("hasRole('VIEWER')");
    }
}
