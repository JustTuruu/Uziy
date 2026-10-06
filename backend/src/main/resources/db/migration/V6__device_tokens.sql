-- Push-notification device tokens (FCM). One row per physical token; a token that
-- moves to another account is reassigned by the app, never duplicated.
CREATE TABLE device_tokens (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       VARCHAR(512) NOT NULL UNIQUE,
    platform    VARCHAR(10)  NOT NULL CHECK (platform IN ('ANDROID', 'IOS')),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id);
