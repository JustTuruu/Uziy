package mn.uziy.backend.admin;

import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — an admin {@link UserEntity} to {@link AdminAccountDto} (no hash, no other fields). */
@Component
public class AdminAccountMapper {

    public AdminAccountDto toDto(UserEntity admin) {
        return new AdminAccountDto(admin.getId(), admin.getPhoneNumber(), admin.getCreatedAt());
    }
}
