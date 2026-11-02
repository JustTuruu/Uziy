-- A deleted account must not let the same person earn the same campaigns again by re-registering the number
-- (owner, 2026-11-02). The phone itself is never kept: only a keyed hash (HMAC-SHA256 with the server's
-- PHONE_HASH_SECRET), so the table cannot be read back into numbers without that secret.

-- Campaigns a deleted account had completed (or had inherited), per hashed phone.
CREATE TABLE former_completions (
    phone_hash  CHAR(64) NOT NULL,
    campaign_id BIGINT   NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    PRIMARY KEY (phone_hash, campaign_id)
);

-- What a re-registered account carries over from the deleted accounts of its number. Counts as "already completed"
-- for the feed, the reward and the approval push; never as a response (it has no answers, and paid nothing).
CREATE TABLE inherited_completions (
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, campaign_id)
);
