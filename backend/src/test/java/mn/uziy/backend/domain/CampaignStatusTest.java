package mn.uziy.backend.domain;

import static mn.uziy.backend.domain.CampaignActor.ADMIN;
import static mn.uziy.backend.domain.CampaignActor.COMPANY;
import static mn.uziy.backend.domain.CampaignActor.SYSTEM;
import static mn.uziy.backend.domain.CampaignStatus.ACTIVE;
import static mn.uziy.backend.domain.CampaignStatus.AWAITING_PAYMENT;
import static mn.uziy.backend.domain.CampaignStatus.COMPLETED;
import static mn.uziy.backend.domain.CampaignStatus.PAUSED;
import static mn.uziy.backend.domain.CampaignStatus.PENDING;
import static mn.uziy.backend.domain.CampaignStatus.REJECTED;
import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;

class CampaignStatusTest {

    private record Edge(CampaignActor actor, CampaignStatus from, CampaignStatus to) {
    }

    private static final List<Edge> LEGAL = List.of(
            new Edge(SYSTEM, AWAITING_PAYMENT, PENDING),
            new Edge(ADMIN, PENDING, ACTIVE),
            new Edge(ADMIN, PENDING, REJECTED),
            new Edge(COMPANY, ACTIVE, PAUSED),
            new Edge(COMPANY, ACTIVE, COMPLETED),
            new Edge(COMPANY, PAUSED, ACTIVE),
            new Edge(COMPANY, PAUSED, COMPLETED));

    @Test
    void exhaustiveTable_onlyListedEdgesAreLegal() {
        int checked = 0;
        for (CampaignActor actor : CampaignActor.values()) {
            for (CampaignStatus from : CampaignStatus.values()) {
                for (CampaignStatus to : CampaignStatus.values()) {
                    boolean expected = LEGAL.contains(new Edge(actor, from, to));
                    assertThat(from.canTransitionTo(to, actor))
                            .as("%s: %s -> %s", actor, from, to)
                            .isEqualTo(expected);
                    checked++;
                }
            }
        }
        assertThat(checked).isEqualTo(3 * 6 * 6);
    }

    @Test
    void terminalStatesHaveNoOutgoingTransitions() {
        for (CampaignActor actor : CampaignActor.values()) {
            for (CampaignStatus to : CampaignStatus.values()) {
                assertThat(COMPLETED.canTransitionTo(to, actor)).isFalse();
                assertThat(REJECTED.canTransitionTo(to, actor)).isFalse();
            }
        }
    }

    @Test
    void selfTransitionsAreNeverLegal() {
        for (CampaignActor actor : CampaignActor.values()) {
            for (CampaignStatus s : CampaignStatus.values()) {
                assertThat(s.canTransitionTo(s, actor)).isFalse();
            }
        }
    }

    @Test
    void nullArgumentsAreRejected() {
        assertThat(ACTIVE.canTransitionTo(null, COMPANY)).isFalse();
        assertThat(ACTIVE.canTransitionTo(PAUSED, null)).isFalse();
    }
}
