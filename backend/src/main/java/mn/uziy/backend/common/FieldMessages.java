package mn.uziy.backend.common;

/**
 * Bean-validation messages for request fields, written for the person filling the form. Annotation attributes
 * need compile-time constants, hence one constants class; {@code ApiExceptionHandler} returns the first failing
 * field's message as the error. Constraints without an explicit message fall back to
 * {@code ValidationMessages.properties} (also Mongolian).
 */
public final class FieldMessages {

    public static final String PHONE = "Утасны дугаар 8 оронтой тоо байх ёстой";
    public static final String PASSWORD_REQUIRED = "Нууц үгээ оруулна уу";
    public static final String PASSWORD_LENGTH = "Нууц үг 6–100 тэмдэгт байх ёстой";
    public static final String CODE = "Код 6 оронтой тоо байх ёстой";
    public static final String LAST_NAME_REQUIRED = "Овгоо оруулна уу";
    public static final String FIRST_NAME_REQUIRED = "Нэрээ оруулна уу";
    public static final String NAME_LETTERS = "Овог, нэрт зөвхөн үсэг ашиглана уу";
    public static final String NAME_TOO_LONG = "Овог, нэр хэт урт байна";
    public static final String GENDER_REQUIRED = "Хүйсээ сонгоно уу";
    public static final String BIRTH_DATE_REQUIRED = "Төрсөн өдрөө оруулна уу";
    public static final String CITY_REQUIRED = "Хотоо сонгоно уу";
    public static final String CITY_TOO_LONG = "Хотын нэр хэт урт байна";
    public static final String DISTRICT_TOO_LONG = "Дүүрэг / сумын нэр хэт урт байна";
    public static final String PHONE_NOT_VERIFIED = "Утасны дугаараа баталгаажуулна уу";
    public static final String COMPANY_NAME_REQUIRED = "Компанийн нэрээ оруулна уу";
    public static final String COMPANY_NAME_TOO_LONG = "Компанийн нэр хэт урт байна";

    public static final String PAYOUT_AMOUNT = "Татах дүнгээ оруулна уу";
    public static final String BANK_REQUIRED = "Банкаа сонгоно уу";
    public static final String ACCOUNT_NUMBER_REQUIRED = "Дансны дугаараа оруулна уу";
    public static final String ACCOUNT_NAME_REQUIRED = "Данс эзэмшигчийн нэрийг оруулна уу";

    public static final String TITLE_REQUIRED = "Аяны нэрийг оруулна уу";
    public static final String TITLE_TOO_LONG = "Аяны нэр хэт урт байна";
    public static final String VIDEO_URL_TOO_LONG = "Видеоны холбоос хэт урт байна";
    public static final String TOO_MANY_QUESTIONS = "Асуулт хэт олон байна";
    public static final String QUESTION_REQUIRED = "Асуултынхаа текстийг оруулна уу";
    public static final String QUESTION_TOO_LONG = "Асуулт хэт урт байна";
    public static final String QUESTION_TYPE_REQUIRED = "Асуултын төрлийг сонгоно уу";
    public static final String TOO_MANY_OPTIONS = "Хариултын сонголт хэт олон байна";
    public static final String OPTION_TOO_LONG = "Хариултын сонголт хэт урт байна";

    private FieldMessages() {
    }
}
