-- One sign-in page for companies and admins (owner, 2026-10-22): an admin who signs in on the company login page
-- is handed to the admin panel with a one-time code instead of a token in a URL. A code lives 60 s and is spent
-- once; only its SHA-256 (hex) is stored, so this table cannot sign anybody in.
CREATE TABLE session_handoffs (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash   VARCHAR(64) NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ
);
