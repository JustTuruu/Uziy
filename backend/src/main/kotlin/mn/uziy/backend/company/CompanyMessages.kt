package mn.uziy.backend.company

/** User-facing (Mongolian) error messages of the company use cases. */
object CompanyMessages {
    const val EXACTLY_ONE_DRIVER_MESSAGE =
        "Үзэгчийн тоо эсвэл нэг үзэгчийн урамшууллын аль нэгийг оруулна уу"
    const val WHOLE_TUGRIK_MESSAGE = "Дүнг бүхэл төгрөгөөр оруулна уу"
    const val AMOUNT_TOO_LARGE_MESSAGE = "Дүн хэт их байна"
    const val TOO_MANY_VIEWERS_MESSAGE = "Үзэгчийн тоо хэт их байна"
    const val DURATION_MESSAGE = "Видеоны урт 5–180 секунд байх ёстой"
    const val NO_QUESTIONS_MESSAGE = "Судалгаанд дор хаяж нэг асуулт оруулна уу"
    const val NOT_PAYABLE_MESSAGE =
        "Энэ аяны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй"
    const val PAYMENTS_UNAVAILABLE_MESSAGE = "Төлбөрийн систем хараахан холбогдоогүй байна"
    const val TRANSITION_MESSAGE = "Энэ төлөвөөс шилжих боломжгүй"
}
