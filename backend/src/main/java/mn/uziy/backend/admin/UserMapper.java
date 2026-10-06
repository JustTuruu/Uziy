package mn.uziy.backend.admin;

import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — turns {@link UserEntity} into the admin {@link UserDto}. */
@Component
public class UserMapper {

    public UserDto toDto(UserEntity u) {
        return new UserDto(u.getId(), u.getPhoneNumber(), u.getRole(),
                u.getGender(), u.getAge(), u.getCity(),
                u.getBalance(), u.isVerified(),
                u.getCompanyName(), u.getCreatedAt());
    }
}
