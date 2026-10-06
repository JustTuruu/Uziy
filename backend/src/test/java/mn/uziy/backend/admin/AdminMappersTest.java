package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import mn.uziy.backend.company.CampaignMapper;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.junit.jupiter.api.Test;

class AdminMappersTest {

    @Test
    void userMapperCopiesEveryField() {
        UserEntity u = new UserEntity();
        u.setId(7L);
        u.setPhoneNumber("99001122");
        u.setPasswordHash("x");
        u.setRole(Role.VIEWER);
        u.setGender(Gender.FEMALE);
        u.setBirthDate(LocalDate.now().minusYears(25));
        u.setCity("Дархан");
        u.setBalance(1200.0);
        u.setVerified(true);

        UserDto dto = new UserMapper().toDto(u);

        assertThat(dto.id()).isEqualTo(7L);
        assertThat(dto.phoneNumber()).isEqualTo("99001122");
        assertThat(dto.role()).isEqualTo(Role.VIEWER);
        assertThat(dto.gender()).isEqualTo(Gender.FEMALE);
        assertThat(dto.age()).isEqualTo(25);
        assertThat(dto.city()).isEqualTo("Дархан");
        assertThat(dto.balance()).isEqualTo(1200.0);
        assertThat(dto.isVerified()).isTrue();
    }

    @Test
    void campaignMapperBuildsDetailWithSpentBudget() {
        CampaignEntity c = AdminTestData.campaign(3, CampaignStatus.ACTIVE);

        CampaignDetailDto d = new AdminCampaignMapper(new CampaignMapper()).toDetail(c, "MobiCom", 12L);

        assertThat(d.campaign().id()).isEqualTo(3L);
        assertThat(d.companyId()).isEqualTo(500L);
        assertThat(d.companyName()).isEqualTo("MobiCom");
        assertThat(d.completedViews()).isEqualTo(12L);
        assertThat(d.spentBudget()).isEqualTo(100_000.0);
    }
}
