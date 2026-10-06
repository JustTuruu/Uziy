package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class UserAdminServiceImpl implements UserAdminService {

    private final UserRepository users;
    private final UserMapper mapper;

    public UserAdminServiceImpl(UserRepository users, UserMapper mapper) {
        this.users = users;
        this.mapper = mapper;
    }

    @Override
    public List<UserDto> list() {
        return users.findAll().stream().map(mapper::toDto).toList();
    }

    @Override
    public UserDto get(long userId) {
        return mapper.toDto(users.findById(userId).orElseThrow(() -> new NotFoundException("User not found")));
    }

    @Override
    public UserDto verify(long userId) {
        UserEntity u = users.findById(userId).orElseThrow();
        u.setVerified(true);
        return mapper.toDto(users.save(u));
    }
}
