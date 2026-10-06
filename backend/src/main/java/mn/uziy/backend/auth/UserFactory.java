package mn.uziy.backend.auth;

import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.springframework.stereotype.Component;

/** Pattern: Factory — builds new (unsaved) viewer and company {@link UserEntity} instances. */
@Component
public class UserFactory {

    public UserEntity newViewer(RegisterViewerReq req, String passwordHash) {
        UserEntity user = base(req.phoneNumber(), passwordHash, Role.VIEWER);
        user.setGender(req.gender());
        user.setBirthDate(req.birthDate());
        user.setCity(req.city());
        user.setDistrict(req.district());
        return user;
    }

    public UserEntity newCompany(RegisterCompanyReq req, String passwordHash) {
        UserEntity user = base(req.phoneNumber(), passwordHash, Role.COMPANY);
        user.setCompanyName(req.companyName());
        return user;
    }

    private static UserEntity base(String phone, String passwordHash, Role role) {
        UserEntity user = new UserEntity();
        user.setPhoneNumber(phone);
        user.setPasswordHash(passwordHash);
        user.setRole(role);
        return user;
    }
}
