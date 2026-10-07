-- One-time codes sent to a phone number (registration check, password reset).
-- Only a hash of the code is stored. A new request makes the older rows
-- irrelevant (only the newest row per phone + purpose is ever checked).
CREATE TABLE otp_codes (
    id            BIGSERIAL    PRIMARY KEY,
    phone_number  VARCHAR(20)  NOT NULL,
    purpose       VARCHAR(20)  NOT NULL CHECK (purpose IN ('REGISTER', 'PASSWORD_RESET')),
    code_hash     VARCHAR(100) NOT NULL,
    expires_at    TIMESTAMPTZ  NOT NULL,
    attempts      INT          NOT NULL DEFAULT 0,
    consumed      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL
);

CREATE INDEX idx_otp_phone_purpose_created ON otp_codes(phone_number, purpose, created_at DESC);
