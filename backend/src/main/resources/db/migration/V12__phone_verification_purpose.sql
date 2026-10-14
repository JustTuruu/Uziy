-- Password reset now proves the phone the same way registration does: the viewer texts a code to verify.mn
-- (owner, 2026-10-14). A check records what it is for and can only be spent for that.
ALTER TABLE phone_verifications
    ADD COLUMN purpose VARCHAR(20) NOT NULL DEFAULT 'REGISTER'
        CHECK (purpose IN ('REGISTER', 'PASSWORD_RESET'));

-- The old reset codes were only ever written to the server log; nothing reads them any more.
DROP TABLE IF EXISTS otp_codes;
