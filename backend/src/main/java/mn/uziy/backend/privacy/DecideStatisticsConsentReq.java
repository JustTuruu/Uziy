package mn.uziy.backend.privacy;

import jakarta.validation.constraints.NotNull;
import mn.uziy.backend.common.FieldMessages;

public record DecideStatisticsConsentReq(@NotNull(message = FieldMessages.CONSENT_REQUIRED) Boolean granted) {
}
