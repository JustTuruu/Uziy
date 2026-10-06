package mn.uziy.backend.notification;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.lang.reflect.Method;
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

/** HTTP contract of the device endpoints: status codes, validation and the caller's id. */
class DeviceControllerTest {

    private final DeviceRegistrationService devices = mock(DeviceRegistrationService.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new DeviceController(devices))
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
    void registerReturns204AndPassesTheCallersId() throws Exception {
        mvc.perform(post("/viewer/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"abc\",\"platform\":\"ANDROID\"}"))
                .andExpect(status().isNoContent());

        verify(devices).register(42L, "abc", DevicePlatform.ANDROID);
    }

    @Test
    void blankTokenIs400() throws Exception {
        mvc.perform(post("/viewer/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"  \",\"platform\":\"IOS\"}"))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(devices);
    }

    @Test
    void tokenLongerThan512Is400AndExactly512Is204() throws Exception {
        mvc.perform(post("/viewer/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"" + "a".repeat(513) + "\",\"platform\":\"IOS\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/viewer/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"" + "a".repeat(512) + "\",\"platform\":\"IOS\"}"))
                .andExpect(status().isNoContent());
    }

    @Test
    void missingOrUnknownPlatformIs400() throws Exception {
        mvc.perform(post("/viewer/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"abc\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/viewer/devices").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"abc\",\"platform\":\"WINDOWS\"}"))
                .andExpect(status().isBadRequest());

        verify(devices, never()).register(42L, "abc", DevicePlatform.ANDROID);
    }

    @Test
    void unregisterReturns204AndPassesTheCallersId() throws Exception {
        mvc.perform(delete("/viewer/devices").param("token", "abc")).andExpect(status().isNoContent());

        verify(devices).unregister(42L, "abc");
    }

    @Test
    void unregisterWithoutOrBlankTokenIs400() throws Exception {
        mvc.perform(delete("/viewer/devices")).andExpect(status().isBadRequest());
        mvc.perform(delete("/viewer/devices").param("token", " ")).andExpect(status().isBadRequest());

        verifyNoInteractions(devices);
    }

    @Test
    void bothEndpointsAreViewerOnly() throws Exception {
        for (Method m : DeviceController.class.getDeclaredMethods()) {
            org.assertj.core.api.Assertions.assertThat(m.getAnnotation(PreAuthorize.class).value())
                    .isEqualTo("hasRole('VIEWER')");
        }
    }
}
