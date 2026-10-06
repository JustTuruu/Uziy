package mn.uziy.backend.auth;

import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.jspecify.annotations.Nullable;

public record Me(
        long id,
        String phoneNumber,
        Role role,
        @Nullable Gender gender,
        @Nullable Integer age,
        @Nullable String city,
        double balance,
        boolean isVerified,
        @Nullable String companyName) {

    public static Me of(UserEntity u) {
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
