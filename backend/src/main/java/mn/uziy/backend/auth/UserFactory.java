package mn.uziy.backend.auth;

import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Component;

/** Pattern: Factory — builds new (unsaved) viewer, company and admin {@link UserEntity} instances. */
@Component
public class UserFactory {

    public UserEntity newViewer(RegisterViewerReq req, String passwordHash) {
        UserEntity user = base(req.phoneNumber(), passwordHash, Role.VIEWER);
        user.setLastName(req.lastName().strip());
        user.setFirstName(req.firstName().strip());
        user.setGender(req.gender());
        user.setBirthDate(req.birthDate());
        user.setCity(req.city());
        user.setDistrict(req.district());
        return user;
    }

    /** A company account an admin opens (companies cannot register themselves). */
    public UserEntity newCompany(String phoneNumber, String companyName, String passwordHash) {
        UserEntity user = base(phoneNumber, passwordHash, Role.COMPANY);
        user.setCompanyName(companyName.strip());
        return user;
    }

    /** An admin account another admin opens (admins are never self-created). */
    public UserEntity newAdmin(String phoneNumber, String passwordHash) {
        return base(phoneNumber, passwordHash, Role.ADMIN);
    }

    private static UserEntity base(String phone, String passwordHash, Role role) {
        UserEntity user = new UserEntity();
        user.setPhoneNumber(phone);
        user.setPasswordHash(passwordHash);
        user.setRole(role);
        return user;
    }
}
