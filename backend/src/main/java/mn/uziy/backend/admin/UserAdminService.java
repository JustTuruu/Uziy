package mn.uziy.backend.admin;

import java.util.List;

/** The admin's view of, and actions on, user accounts. Every read is written to the data access log. */
public interface UserAdminService {
    List<UserDto> list(long adminId);

    UserDto get(long userId, long adminId);

    UserDto verify(long userId);
}
