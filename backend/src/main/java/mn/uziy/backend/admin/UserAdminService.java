package mn.uziy.backend.admin;

import java.util.List;

/** The admin's view of, and actions on, user accounts. */
public interface UserAdminService {
    List<UserDto> list();

    UserDto get(long userId);

    UserDto verify(long userId);
}
