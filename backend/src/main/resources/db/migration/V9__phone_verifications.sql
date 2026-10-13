-- Registration proves phone ownership through verify.mn: the user texts a 6-digit code FROM their phone
-- to the 144773 short code. One row per verify.mn session; the row's random UUID is the id the app polls
-- with and then sends with the registration form. A row can finish exactly one registration (claimed).
CREATE TABLE phone_verifications (
    id                   UUID         PRIMARY KEY,
    phone_number         VARCHAR(20)  NOT NULL,
    provider_session_id  VARCHAR(100) NOT NULL,
    status               VARCHAR(20)  NOT NULL CHECK (status IN ('PENDING', 'VERIFIED', 'EXPIRED')),
    expires_at           TIMESTAMPTZ  NOT NULL,
    verified_at          TIMESTAMPTZ,
    claimed              BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMPTZ  NOT NULL
);

CREATE INDEX idx_phone_verifications_phone_created ON phone_verifications(phone_number, created_at DESC);
