package mn.uziy.backend.admin;

import java.time.OffsetDateTime;

/** One admin account as the "Админууд" page lists it. */
public record AdminAccountDto(long id, String phoneNumber, OffsetDateTime createdAt) {
}
