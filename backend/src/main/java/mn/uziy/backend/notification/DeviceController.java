package mn.uziy.backend.notification;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for a viewer's push-token registration. */
@RestController
public class DeviceController {

    private final DeviceRegistrationService devices;

    public DeviceController(DeviceRegistrationService devices) {
        this.devices = devices;
    }

    @PostMapping("/viewer/devices")
    @PreAuthorize("hasRole('VIEWER')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void register(@Valid @RequestBody RegisterDeviceReq body, @Auth JwtPrincipal principal) {
        devices.register(principal.userId(), body.token(), body.platform());
    }

    @DeleteMapping("/viewer/devices")
    @PreAuthorize("hasRole('VIEWER')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unregister(
            @RequestParam("token") @NotBlank @Size(max = DeviceTokenEntity.MAX_TOKEN_LENGTH) String token,
            @Auth JwtPrincipal principal) {
        devices.unregister(principal.userId(), token);
    }
}
