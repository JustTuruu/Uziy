-- An admin's password alone no longer signs in (owner, 2026-10-22): after the password the admin texts a code from
-- the account's phone to verify.mn, exactly like a viewer at registration. Such a check is opened only by the login
-- itself (never by the public endpoint) and can only be spent to finish that login.
ALTER TABLE phone_verifications DROP CONSTRAINT IF EXISTS phone_verifications_purpose_check;
ALTER TABLE phone_verifications
    ADD CONSTRAINT phone_verifications_purpose_check
        CHECK (purpose IN ('REGISTER', 'PASSWORD_RESET', 'ADMIN_LOGIN'));
