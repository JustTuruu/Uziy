-- When the password last changed (2026-10-22). A token issued before this moment is refused, so a password reset
-- signs out every phone or browser that still holds an old token. NULL = never changed since registration.
ALTER TABLE users ADD COLUMN credentials_changed_at TIMESTAMPTZ;
