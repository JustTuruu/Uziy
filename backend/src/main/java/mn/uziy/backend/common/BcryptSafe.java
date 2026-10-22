package mn.uziy.backend.common;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.nio.charset.StandardCharsets;

/**
 * A new password BCrypt can hash: at most {@link #MAX_BYTES} bytes in UTF-8. BCrypt refuses longer input with an
 * exception, and a Cyrillic letter takes two bytes, so 37 Cyrillic letters passed the 100-character limit and
 * ended in a 500 (audit 2026-10-22). Null is left to {@code @NotNull}.
 */
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = BcryptSafe.Validator.class)
public @interface BcryptSafe {

    int MAX_BYTES = 72;

    String message() default FieldMessages.PASSWORD_TOO_LONG;

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

    class Validator implements ConstraintValidator<BcryptSafe, String> {
        @Override
        public boolean isValid(String value, ConstraintValidatorContext context) {
            return value == null || value.getBytes(StandardCharsets.UTF_8).length <= MAX_BYTES;
        }
    }
}
