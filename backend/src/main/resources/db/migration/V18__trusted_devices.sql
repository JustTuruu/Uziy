-- Companies prove their phone at login like admins (owner, 2026-10-22), with their own purpose so a company's
-- check can never finish an admin's login (or the other way round).
ALTER TABLE phone_verifications DROP CONSTRAINT IF EXISTS phone_verifications_purpose_check;
ALTER TABLE phone_verifications
    ADD CONSTRAINT phone_verifications_purpose_check
        CHECK (purpose IN ('REGISTER', 'PASSWORD_RESET', 'ADMIN_LOGIN', 'COMPANY_LOGIN'));

-- "Ask for the phone only on an unrecognised browser": a browser that proved the phone keeps a random secret for
-- 30 days. Only the secret's SHA-256 (hex) is stored, so this table cannot sign anybody in. A password change makes
-- older rows useless (the login compares created_at with users.credentials_changed_at) and also deletes them.
CREATE TABLE trusted_devices (
    id            BIGSERIAL   PRIMARY KEY,
    user_id       BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash    VARCHAR(64) NOT NULL UNIQUE,
    -- The browser family only ("Chrome", "Safari"), never the full User-Agent.
    label         VARCHAR(40),
    created_at    TIMESTAMPTZ NOT NULL,
    expires_at    TIMESTAMPTZ NOT NULL,
    last_used_at  TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_trusted_devices_user ON trusted_devices(user_id, last_used_at DESC);
