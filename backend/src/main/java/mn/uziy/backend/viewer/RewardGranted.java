package mn.uziy.backend.viewer;

import mn.uziy.backend.common.event.DomainEvent;

/** Pattern: Observer — raised inside the reward transaction once the balance is credited. */
public record RewardGranted(long userId, long campaignId, double reward) implements DomainEvent {
}
