package mn.uziy.backend.auth;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.MongolianRegions;
import org.jspecify.annotations.Nullable;

/**
 * Where a new viewer lives must be a real place: the capital or an aimag from the list, and in the capital one
 * of its districts (targeting and analytics count by these exact names). Outside the capital the district
 * (сум) is optional free text.
 */
public final class ViewerLocationRule {

    public static final String UNKNOWN_CITY = "Аймаг эсвэл хотоо жагсаалтаас сонгоно уу";
    public static final String DISTRICT_REQUIRED = "Улаанбаатарт амьдардаг бол дүүргээ сонгоно уу";
    public static final String UNKNOWN_DISTRICT = "Дүүргээ жагсаалтаас сонгоно уу";

    private ViewerLocationRule() {
    }

    /** @throws BadRequestException with one of the messages above */
    public static void check(String city, @Nullable String district) {
        if (!MongolianRegions.isCity(city)) {
            throw new BadRequestException(UNKNOWN_CITY);
        }
        if (!MongolianRegions.CAPITAL.equals(city)) {
            return;
        }
        if (district == null || district.isBlank()) {
            throw new BadRequestException(DISTRICT_REQUIRED);
        }
        if (!MongolianRegions.isCapitalDistrict(district)) {
            throw new BadRequestException(UNKNOWN_DISTRICT);
        }
    }
}
