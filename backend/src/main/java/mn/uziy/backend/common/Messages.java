package mn.uziy.backend.common;

/**
 * User-facing wording that several services share (Cyrillic Mongolian, polite "Та"). Kept in one place so the
 * same failure always reads the same in the app and both panels.
 */
public final class Messages {

    public static final String USER_NOT_FOUND = "Хэрэглэгч олдсонгүй";
    /** Company and admin side. */
    public static final String CAMPAIGN_NOT_FOUND = "Аян олдсонгүй";
    /** Viewer side: also used when the viewer is outside the audience, so targeting cannot be probed. */
    public static final String OFFER_NOT_FOUND = "Энэ урамшуулал олдсонгүй эсвэл дууссан байна";
    public static final String PHONE_TAKEN = "Энэ утасны дугаар аль хэдийн бүртгэлтэй байна. Нэвтэрч орно уу";
    public static final String INSUFFICIENT_BALANCE = "Хэтэвчний үлдэгдэл хүрэлцэхгүй байна";
    public static final String BUSY = "Түр завгүй байна. Дахин оролдоно уу";

    private Messages() {
    }
}
