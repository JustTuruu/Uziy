package mn.uziy.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/**
 * Platform account (viewer, company or admin). {@code verified} maps to
 * {@code is_verified}; it is set by the admin at the first approved payout, not at registration.
 */
@Entity
@Table(name = "users")
public class UserEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "phone_number", nullable = false, unique = true, length = 15)
    private String phoneNumber = "";

    @Column(name = "password_hash", nullable = false)
    private String passwordHash = "";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role = Role.VIEWER;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Gender gender;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    @Column(length = 50)
    private String city;

    @Column(length = 50)
    private String district;

    @Column(nullable = false)
    private double balance = 0.0;

    @Column(name = "is_verified", nullable = false)
    private boolean verified = false;

    @Column(name = "company_name", length = 120)
    private String companyName;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    public UserEntity() {
    }

    public @Nullable Long getId() { return id; }
    public void setId(@Nullable Long id) { this.id = id; }

    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }

    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }

    public Role getRole() { return role; }
    public void setRole(Role role) { this.role = role; }

    public @Nullable Gender getGender() { return gender; }
    public void setGender(@Nullable Gender gender) { this.gender = gender; }

    public @Nullable LocalDate getBirthDate() { return birthDate; }
    public void setBirthDate(@Nullable LocalDate birthDate) { this.birthDate = birthDate; }

    public @Nullable String getCity() { return city; }
    public void setCity(@Nullable String city) { this.city = city; }

    public @Nullable String getDistrict() { return district; }
    public void setDistrict(@Nullable String district) { this.district = district; }

    public double getBalance() { return balance; }
    public void setBalance(double balance) { this.balance = balance; }

    public boolean isVerified() { return verified; }
    public void setVerified(boolean verified) { this.verified = verified; }

    public @Nullable String getCompanyName() { return companyName; }
    public void setCompanyName(@Nullable String companyName) { this.companyName = companyName; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }

    /** Age computed from birth_date. Null for non-viewer accounts. */
    @Transient
    public @Nullable Integer getAge() {
        if (birthDate == null) {
            return null;
        }
        LocalDate today = LocalDate.now();
        int years = today.getYear() - birthDate.getYear();
        if (today.getMonthValue() < birthDate.getMonthValue()
                || (today.getMonthValue() == birthDate.getMonthValue()
                && today.getDayOfMonth() < birthDate.getDayOfMonth())) {
            years -= 1;
        }
        return years;
    }
}
