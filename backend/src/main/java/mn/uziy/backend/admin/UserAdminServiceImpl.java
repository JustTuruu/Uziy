package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class UserAdminServiceImpl implements UserAdminService {

    private final UserRepository users;

    public UserAdminServiceImpl(UserRepository users) {
        this.users = users;
    }

    @Override
    public List<UserDto> list() {
        return users.findAll().stream().map(UserDto::of).toList();
    }

    @Override
    public UserDto get(long userId) {
        return UserDto.of(users.findById(userId).orElseThrow(() -> new NotFoundException("User not found")));
    }

    @Override
    public UserDto verify(long userId) {
        UserEntity u = users.findById(userId).orElseThrow();
        u.setVerified(true);
        return UserDto.of(users.save(u));
    }
}
