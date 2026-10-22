package mn.uziy.backend.account;

/** User-facing (Mongolian) messages of account deletion. */
public final class AccountDeletionMessages {

    public static final String WRONG_PASSWORD = "Нууц үг буруу байна. Дахин оролдоно уу";
    /** Money is on its way to the viewer's bank account; deleting now would leave the request without an owner. */
    public static final String PAYOUT_PENDING =
            "Таны мөнгө татах хүсэлт шалгагдаж байна. Хүсэлт шийдвэрлэгдсэний дараа бүртгэлээ устгана уу";
    /** The account changed while it was being deleted (e.g. the password was reset at the same moment). */
    public static final String NOT_DELETED = "Бүртгэлийг устгаж чадсангүй. Дахин оролдоно уу";

    private AccountDeletionMessages() {
    }
}
