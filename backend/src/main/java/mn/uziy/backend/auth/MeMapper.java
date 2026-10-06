package mn.uziy.backend.auth;

import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — turns a {@link UserEntity} into the {@link Me} response record. */
@Component
public class MeMapper {

    public Me toMe(UserEntity u) {
        return new Me(
                u.getId(),
                u.getPhoneNumber(),
                u.getRole(),
                u.getGender(),
                u.getAge(),
                u.getCity(),
                u.getBalance(),
                u.isVerified(),
                u.getCompanyName());
    }
}
