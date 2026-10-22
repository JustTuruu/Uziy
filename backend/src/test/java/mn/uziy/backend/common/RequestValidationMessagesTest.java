package mn.uziy.backend.common;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Stream;
import mn.uziy.backend.admin.CreateCompanyReq;
import mn.uziy.backend.adminlogin.AdminLoginVerifyReq;
import mn.uziy.backend.auth.LoginReq;
import mn.uziy.backend.auth.RegisterViewerReq;
import mn.uziy.backend.company.CreateCampaignReq;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.passwordreset.ResetPasswordReq;
import mn.uziy.backend.payout.CreatePayoutReq;
import mn.uziy.backend.phoneverify.StartPhoneVerificationReq;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;

/** Every message a form can get back from field validation is Mongolian and names what to fix. */
class RequestValidationMessagesTest {

    private static final String CYRILLIC = ".*[А-Яа-яӨөҮүЁё].*";

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    private Set<String> messages(Object request) {
        return validator.validate(request).stream()
                .map(ConstraintViolation::getMessage)
                .collect(java.util.stream.Collectors.toSet());
    }

    static Stream<Object> invalidRequests() {
        String huge = "x".repeat(5_000);
        return Stream.of(
                new LoginReq("123", ""),
                new RegisterViewerReq("12", "123", " ", "1abc", null, null, "", huge, null),
                new CreateCompanyReq(" ", "abc", "1"),
                new AdminLoginVerifyReq("12", null),
                new ResetPasswordReq("1", null, "1"),
                new StartPhoneVerificationReq("phone", null),
                new CreatePayoutReq(0, "", "", ""),
                new CreateCampaignReq(" ", huge, null, null, null, null, null, huge, null, null, null,
                        List.of(new CreateCampaignReq.NewQuestion(null, null, List.of(huge), null))));
    }

    @ParameterizedTest
    @MethodSource("invalidRequests")
    void everyFieldMessageIsMongolian(Object request) {
        Set<String> messages = messages(request);

        assertThat(messages).isNotEmpty();
        assertThat(messages).allSatisfy(m -> assertThat(m).matches(CYRILLIC));
    }

    @Test
    void theRegistrationFormNamesEachMissingField() {
        Set<String> messages = messages(new RegisterViewerReq("12", "123", "", "", null, null, "", null, null));

        assertThat(messages).contains(FieldMessages.PHONE, FieldMessages.PASSWORD_LENGTH,
                FieldMessages.LAST_NAME_REQUIRED, FieldMessages.FIRST_NAME_REQUIRED,
                FieldMessages.GENDER_REQUIRED, FieldMessages.BIRTH_DATE_REQUIRED, FieldMessages.CITY_REQUIRED,
                FieldMessages.PHONE_NOT_VERIFIED);
    }

    @Test
    void aValidRegistrationHasNoMessages() {
        assertThat(messages(new RegisterViewerReq("88112233", "password1", "Бат", "Болд", Gender.MALE, LocalDate.of(2000, 1, 1),
                "Улаанбаатар", UUID.randomUUID()))).isEmpty();
    }

    private Set<String> nameMessages(String lastName, String firstName) {
        return messages(new RegisterViewerReq("88112233", "password1", lastName, firstName, Gender.MALE,
                LocalDate.of(2000, 1, 1), "Улаанбаатар", UUID.randomUUID()));
    }

    @Test
    void realNamesAreAccepted() {
        assertThat(nameMessages("Оюун-Эрдэнэ", "Төрболд")).isEmpty();
        assertThat(nameMessages("Бат-Өлзий", "Үүрцайх")).isEmpty();
        assertThat(nameMessages("Oyunukhaan", "Turbold")).isEmpty();
        assertThat(nameMessages(" Бат ", "Болд Эрдэнэ")).isEmpty();
    }

    @Test
    void aNameWithDigitsOrSymbolsIsRefusedInMongolian() {
        assertThat(nameMessages("Бат1", "Болд")).containsExactly(FieldMessages.NAME_LETTERS);
        assertThat(nameMessages("Бат", "-Болд")).containsExactly(FieldMessages.NAME_LETTERS);
        assertThat(nameMessages("Бат", "Болд@")).containsExactly(FieldMessages.NAME_LETTERS);
    }

    @Test
    void anOverlongNameIsRefused() {
        assertThat(nameMessages("Б".repeat(RegisterViewerReq.NAME_MAX + 1), "Болд"))
                .contains(FieldMessages.NAME_TOO_LONG);
    }

    @Test
    void theAdminCompanyFormNamesEachBadField() {
        assertThat(messages(new CreateCompanyReq(" ", "12", "1"))).containsExactlyInAnyOrder(
                FieldMessages.COMPANY_NAME_REQUIRED, FieldMessages.PHONE, FieldMessages.PASSWORD_LENGTH);
        assertThat(messages(new CreateCompanyReq("MobiCom", "88112233", null)))
                .containsExactly(FieldMessages.PASSWORD_LENGTH);
        assertThat(messages(new CreateCompanyReq("MobiCom", "88112233", "temp-pass1"))).isEmpty();
    }

    /** 37 Cyrillic letters are 74 bytes: past BCrypt's 72, which used to end in a 500 (audit 2026-10-22). */
    @Test
    void aTemporaryCompanyPasswordMustFitBcrypt() {
        assertThat(messages(new CreateCompanyReq("MobiCom", "88112233", "ж".repeat(37)))).isNotEmpty();
    }

    @Test
    void theAdminSecondStepNeedsThePhoneAndTheCheck() {
        assertThat(messages(new AdminLoginVerifyReq("12", null))).containsExactlyInAnyOrder(
                FieldMessages.PHONE, FieldMessages.PHONE_NOT_VERIFIED);
        assertThat(messages(new AdminLoginVerifyReq("88112233", UUID.randomUUID()))).isEmpty();
    }

    @Test
    void theLoginFormAsksForPhoneAndPassword() {
        assertThat(messages(new LoginReq("123", " "))).containsExactlyInAnyOrder(
                FieldMessages.PHONE, FieldMessages.PASSWORD_REQUIRED);
    }

    @Test
    void sharedUserFacingMessagesAreMongolian() throws IllegalAccessException {
        for (Class<?> type : List.of(Messages.class, FieldMessages.class)) {
            for (Field f : type.getDeclaredFields()) {
                if (Modifier.isStatic(f.getModifiers()) && f.getType() == String.class) {
                    assertThat((String) f.get(null)).as(type.getSimpleName() + "." + f.getName()).matches(CYRILLIC);
                }
            }
        }
    }
}
