package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.uziy.backend.common.BadRequestException;
import org.junit.jupiter.api.Test;

class ViewerLocationRuleTest {

    @Test
    void theCapitalWithAListedDistrictIsAccepted() {
        assertThatCode(() -> ViewerLocationRule.check("Улаанбаатар", "Сонгинохайрхан")).doesNotThrowAnyException();
    }

    @Test
    void theCapitalNeedsADistrict() {
        assertThatThrownBy(() -> ViewerLocationRule.check("Улаанбаатар", null))
                .isInstanceOf(BadRequestException.class).hasMessage(ViewerLocationRule.DISTRICT_REQUIRED);
        assertThatThrownBy(() -> ViewerLocationRule.check("Улаанбаатар", "  "))
                .hasMessage(ViewerLocationRule.DISTRICT_REQUIRED);
    }

    @Test
    void aCapitalDistrictMustBeFromTheList() {
        assertThatThrownBy(() -> ViewerLocationRule.check("Улаанбаатар", "13-р хороолол"))
                .isInstanceOf(BadRequestException.class).hasMessage(ViewerLocationRule.UNKNOWN_DISTRICT);
    }

    @Test
    void anAimagNeedsNoDistrictAndTakesAnySum() {
        assertThatCode(() -> ViewerLocationRule.check("Дархан-Уул", null)).doesNotThrowAnyException();
        assertThatCode(() -> ViewerLocationRule.check("Ховд", "Жаргалант")).doesNotThrowAnyException();
    }

    @Test
    void aPlaceOutsideTheListIsRefused() {
        assertThatThrownBy(() -> ViewerLocationRule.check("Дархан", null))
                .isInstanceOf(BadRequestException.class).hasMessage(ViewerLocationRule.UNKNOWN_CITY);
        assertThatThrownBy(() -> ViewerLocationRule.check("Бусад", null)).hasMessage(ViewerLocationRule.UNKNOWN_CITY);
    }
}
