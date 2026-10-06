package mn.uziy.backend.company;

/** User-facing (Mongolian) error messages of the company use cases. */
public final class CompanyMessages {

    public static final String EXACTLY_ONE_DRIVER_MESSAGE =
            "Үзэгчийн тоо эсвэл нэг үзэгчийн урамшууллын аль нэгийг оруулна уу";
    public static final String WHOLE_TUGRIK_MESSAGE = "Дүнг бүхэл төгрөгөөр оруулна уу";
    public static final String AMOUNT_TOO_LARGE_MESSAGE = "Дүн хэт их байна";
    public static final String TOO_MANY_VIEWERS_MESSAGE = "Үзэгчийн тоо хэт их байна";
    public static final String DURATION_MESSAGE = "Видеоны урт 5–180 секунд байх ёстой";
    public static final String NO_QUESTIONS_MESSAGE = "Судалгаанд дор хаяж нэг асуулт оруулна уу";
    public static final String NOT_PAYABLE_MESSAGE =
            "Энэ аяны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй";
    public static final String PAYMENTS_UNAVAILABLE_MESSAGE = "Төлбөрийн систем хараахан холбогдоогүй байна";
    public static final String TRANSITION_MESSAGE = "Энэ төлөвөөс шилжих боломжгүй";

    private CompanyMessages() {
    }
}
