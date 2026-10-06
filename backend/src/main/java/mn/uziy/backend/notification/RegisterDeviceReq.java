package mn.uziy.backend.notification;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Body of {@code POST /viewer/devices}. */
public record RegisterDeviceReq(
        @NotBlank @Size(max = DeviceTokenEntity.MAX_TOKEN_LENGTH) String token,
        @NotNull DevicePlatform platform) {
}
