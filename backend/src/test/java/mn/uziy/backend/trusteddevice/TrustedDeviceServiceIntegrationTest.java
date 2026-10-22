package mn.uziy.backend.trusteddevice;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/** The trust rules that live in SQL ({@link TrustedDeviceRepository}), against Postgres with every migration. */
class TrustedDeviceServiceIntegrationTest extends AbstractApiIntegrationTest {

    @Autowired DeviceTrust trust;
    @Autowired TrustedDeviceRevoker revoker;

    private long rows(long userId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM trusted_devices WHERE user_id = ?", Long.class, userId);
    }

    @Test
    void aTrustedBrowserIsRecognisedForItsOwnAccountOnly() {
        long company = company();
        long other = company();
        String secret = trust.trust(company, "Chrome/141.0").secret();

        assertThat(trust.recognises(company, secret)).isTrue();
        assertThat(trust.recognises(other, secret)).isFalse();
    }

    @Test
    void onlyTheHashAndTheBrowserFamilyAreStored() {
        long company = company();
        String secret = trust.trust(company, "Mozilla/5.0 Chrome/141.0 Safari/537.36").secret();

        assertThat(jdbc.queryForObject("SELECT token_hash FROM trusted_devices WHERE user_id = ?", String.class,
                company)).isEqualTo(DeviceSecrets.hash(secret));
        assertThat(jdbc.queryForObject("SELECT label FROM trusted_devices WHERE user_id = ?", String.class,
                company)).isEqualTo("Chrome");
    }

    @Test
    void recognisingABrowserRecordsItsUse() {
        long company = company();
        String secret = trust.trust(company, null).secret();
        jdbc.update("UPDATE trusted_devices SET last_used_at = now() - INTERVAL '3 days' WHERE user_id = ?", company);

        trust.recognises(company, secret);

        assertThat(jdbc.queryForObject("SELECT last_used_at > now() - INTERVAL '1 minute' FROM trusted_devices "
                + "WHERE user_id = ?", Boolean.class, company)).isTrue();
    }

    @Test
    void anExpiredBrowserIsAStranger() {
        long company = company();
        String secret = trust.trust(company, null).secret();
        jdbc.update("UPDATE trusted_devices SET expires_at = now() - INTERVAL '1 second' WHERE user_id = ?", company);

        assertThat(trust.recognises(company, secret)).isFalse();
    }

    @Test
    void aPasswordChangeMakesEveryOlderBrowserAStrangerEvenIfItsRowIsLeft() {
        long company = company();
        String before = trust.trust(company, null).secret();
        jdbc.update("UPDATE users SET credentials_changed_at = now() WHERE id = ?", company);
        String after = trust.trust(company, null).secret();

        assertThat(trust.recognises(company, before)).isFalse();
        assertThat(trust.recognises(company, after)).isTrue();
    }

    @Test
    void atMostTenBrowsersAreKeptAndTheLeastRecentlyUsedGoesFirst() {
        long company = company();
        List<String> secrets = new ArrayList<>();
        for (int i = 0; i < TrustedDeviceServiceImpl.MAX_DEVICES_PER_USER; i++) {
            secrets.add(trust.trust(company, null).secret());
        }
        // The oldest browser was used just now, so the second one is now the least recently used.
        trust.recognises(company, secrets.get(0));

        String eleventh = trust.trust(company, null).secret();

        assertThat(rows(company)).isEqualTo(TrustedDeviceServiceImpl.MAX_DEVICES_PER_USER);
        assertThat(trust.recognises(company, secrets.get(1))).isFalse();
        assertThat(trust.recognises(company, secrets.get(0))).isTrue();
        assertThat(trust.recognises(company, eleventh)).isTrue();
    }

    @Test
    void trustingABrowserAlsoClearsTheAccountsExpiredOnes() {
        long company = company();
        trust.trust(company, null);
        jdbc.update("UPDATE trusted_devices SET expires_at = now() - INTERVAL '1 day' WHERE user_id = ?", company);

        trust.trust(company, null);

        assertThat(rows(company)).isEqualTo(1);
    }

    @Test
    void revokeAllForgetsOneAccountsBrowsersOnly() {
        long company = company();
        long other = company();
        trust.trust(company, null);
        trust.trust(company, null);
        String othersSecret = trust.trust(other, null).secret();

        assertThat(revoker.revokeAll(company)).isEqualTo(2);

        assertThat(rows(company)).isZero();
        assertThat(trust.recognises(other, othersSecret)).isTrue();
    }

    @Test
    void deletingTheAccountRowDeletesItsBrowsers() {
        long company = company();
        trust.trust(company, null);

        jdbc.update("DELETE FROM users WHERE id = ?", company);

        assertThat(rows(company)).isZero();
    }
}
