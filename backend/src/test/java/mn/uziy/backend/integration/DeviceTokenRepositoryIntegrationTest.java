package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.domain.ViewHistoryEntity;
import mn.uziy.backend.domain.ViewHistoryRepository;
import mn.uziy.backend.notification.DevicePlatform;
import mn.uziy.backend.notification.DeviceRegistrationService;
import mn.uziy.backend.notification.DeviceTokenEntity;
import mn.uziy.backend.notification.DeviceTokenRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * The audience query against real Postgres, plus the register/unregister service. Also proves the
 * full Spring context boots with push disabled (logging sender). Each test creates its own users
 * and uses its own unique token prefix, so nothing depends on other rows or on test order.
 */
@SpringBootTest
@Testcontainers
class DeviceTokenRepositoryIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_push_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    private static final AtomicInteger SEQ = new AtomicInteger(1000);
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 6);
    private static final LocalDate AFTER_45 = TODAY.minusYears(46);   // exclusive lower bound for maxAge 45
    private static final LocalDate BEFORE_18 = TODAY.minusYears(18);  // inclusive upper bound for minAge 18

    @Autowired UserRepository users;
    @Autowired DeviceTokenRepository tokens;
    @Autowired ViewHistoryRepository history;
    @Autowired DeviceRegistrationService registration;

    private UserEntity user(Role role, Gender gender, LocalDate birth, String city) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber("9" + SEQ.incrementAndGet() + "00");
        u.setPasswordHash("x");
        u.setRole(role);
        u.setGender(gender);
        u.setBirthDate(birth);
        u.setCity(city);
        return users.save(u);
    }

    private String token(UserEntity u, String name) {
        registration.register(u.getId(), name, DevicePlatform.ANDROID);
        return name;
    }

    private List<String> audience(long campaignId, String gender, String city, String prefix) {
        return tokens.findTokensForCampaign(campaignId, gender, city, AFTER_45, BEFORE_18).stream()
                .filter(t -> t.startsWith(prefix)).toList();
    }

    @Test
    void genderAllMatchesEveryoneAndASpecificGenderOnlyThatGender() {
        String p = "g1-";
        String m = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар"), p + "m");
        String f = token(user(Role.VIEWER, Gender.FEMALE, TODAY.minusYears(30), "Улаанбаатар"), p + "f");

        assertThat(audience(1, "ALL", "ALL", p)).containsExactlyInAnyOrder(m, f);
        assertThat(audience(1, "MALE", "ALL", p)).containsExactly(m);
        assertThat(audience(1, "FEMALE", "ALL", p)).containsExactly(f);
    }

    @Test
    void ageBoundsAreInclusiveOfMinAndMaxAndExcludeOutsiders() {
        String p = "a1-";
        String exactly18 = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(18), "Улаанбаатар"), p + "18");
        String turns18Tomorrow = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(18).plusDays(1), "Улаанбаатар"), p + "17");
        String exactly45 = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(45), "Улаанбаатар"), p + "45");
        String justTurned46 = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(46), "Улаанбаатар"), p + "46");
        String oldestStill45 = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(46).plusDays(1), "Улаанбаатар"), p + "45b");

        assertThat(audience(1, "ALL", "ALL", p))
                .containsExactlyInAnyOrder(exactly18, exactly45, oldestStill45)
                .doesNotContain(turns18Tomorrow, justTurned46);
    }

    @Test
    void cityAllMatchesEveryCityAndASpecificCityOnlyThatCity() {
        String p = "c1-";
        String ub = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар"), p + "ub");
        String dk = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Дархан"), p + "dk");

        assertThat(audience(1, "ALL", "ALL", p)).containsExactlyInAnyOrder(ub, dk);
        assertThat(audience(1, "ALL", "Дархан", p)).containsExactly(dk);
    }

    @Test
    void viewersWhoAlreadyCompletedTheCampaignAreExcluded() {
        String p = "v1-";
        UserEntity seen = user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар");
        UserEntity fresh = user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар");
        token(seen, p + "seen");
        String freshToken = token(fresh, p + "fresh");
        ViewHistoryEntity h = new ViewHistoryEntity();
        h.setUserId(seen.getId());
        h.setCampaignId(1L);
        h.setRewardPaid(700);
        history.save(h);

        assertThat(audience(1, "ALL", "ALL", p)).containsExactly(freshToken);
        // Completing campaign 1 does not hide campaign 2.
        assertThat(audience(2, "ALL", "ALL", p)).hasSize(2);
    }

    @Test
    void nonViewersAndUsersWithoutBirthDateAreExcluded() {
        String p = "n1-";
        token(user(Role.COMPANY, null, TODAY.minusYears(30), null), p + "company");
        token(user(Role.VIEWER, Gender.MALE, null, "Улаанбаатар"), p + "nobirth");
        String ok = token(user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар"), p + "ok");

        assertThat(audience(1, "ALL", "ALL", p)).containsExactly(ok);
    }

    @Test
    void registeringAnExistingTokenMovesItToTheNewUserWithoutDuplicating() {
        UserEntity a = user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар");
        UserEntity b = user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар");
        registration.register(a.getId(), "move-1", DevicePlatform.ANDROID);
        registration.register(b.getId(), "move-1", DevicePlatform.IOS);

        DeviceTokenEntity row = tokens.findByToken("move-1").orElseThrow();
        assertThat(row.getUserId()).isEqualTo(b.getId());
        assertThat(row.getPlatform()).isEqualTo(DevicePlatform.IOS);
        assertThat(tokens.findAll().stream().filter(t -> t.getToken().equals("move-1"))).hasSize(1);
    }

    @Test
    void unregisterRemovesOnlyTheOwnersTokenAndDeadTokensCanBeBulkDeleted() {
        UserEntity a = user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар");
        UserEntity b = user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар");
        registration.register(a.getId(), "del-a", DevicePlatform.ANDROID);
        registration.register(b.getId(), "del-b1", DevicePlatform.ANDROID);
        registration.register(b.getId(), "del-b2", DevicePlatform.ANDROID);

        registration.unregister(b.getId(), "del-a");
        assertThat(tokens.findByToken("del-a")).isPresent();
        registration.unregister(a.getId(), "del-a");
        assertThat(tokens.findByToken("del-a")).isEmpty();

        assertThat(tokens.deleteAllByTokenIn(List.of("del-b1", "del-b2", "unknown"))).isEqualTo(2);
        assertThat(tokens.findByToken("del-b1")).isEmpty();
    }

    @Test
    void deletingAUserCascadesToTheirTokens() {
        UserEntity u = user(Role.VIEWER, Gender.MALE, TODAY.minusYears(30), "Улаанбаатар");
        registration.register(u.getId(), "cascade-1", DevicePlatform.ANDROID);

        users.deleteById(u.getId());

        assertThat(tokens.findByToken("cascade-1")).isEmpty();
    }
}
