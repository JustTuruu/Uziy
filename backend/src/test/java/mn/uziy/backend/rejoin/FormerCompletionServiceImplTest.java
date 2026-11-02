package mn.uziy.backend.rejoin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Set;
import org.junit.jupiter.api.Test;

class FormerCompletionServiceImplTest {

    private static final String PHONE = "99112233";

    private final FormerCompletionRepository repository = mock(FormerCompletionRepository.class);
    private final PhoneFingerprint fingerprint = new PhoneFingerprint("unit-test-secret-0123456789abcdef");
    private final FormerCompletionServiceImpl service = new FormerCompletionServiceImpl(repository, fingerprint);

    @Test
    void aDeletedAccountsCompletionsAreFiledUnderTheHashNeverThePhone() {
        service.rememberBeforeDeletion(42L, PHONE);

        verify(repository).rememberCompletionsOf(42L, fingerprint.of(PHONE));
    }

    @Test
    void aNewAccountInheritsUnderTheSameHash() {
        service.carryOverToNewAccount(77L, PHONE);

        verify(repository).inheritInto(77L, fingerprint.of(PHONE));
    }

    @Test
    void readsComeStraightFromTheInheritedCompletions() {
        when(repository.inheritedCampaignIds(77L)).thenReturn(Set.of(5L, 6L));
        when(repository.isInherited(77L, 5L)).thenReturn(true);

        assertThat(service.inheritedCampaignIds(77L)).containsExactlyInAnyOrder(5L, 6L);
        assertThat(service.isInherited(77L, 5L)).isTrue();
        assertThat(service.isInherited(77L, 9L)).isFalse();
    }
}
