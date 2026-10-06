package mn.uziy.backend.admin;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import org.jspecify.annotations.Nullable;

public record UserDto(
        long id,
        String phoneNumber,
        Role role,
        @Nullable Gender gender,
        @Nullable Integer age,
        @Nullable String city,
        double balance,
        boolean isVerified,
        @Nullable String companyName,
        OffsetDateTime createdAt) {
}
