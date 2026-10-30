-- The company and admin panels became one app (2026-10-30), so an admin keeps the session of the page they signed
-- in on and no one-time handoff code is needed. The table only ever held 60-second codes (their hashes).
DROP TABLE session_handoffs;
