-- A viewer's family name (овог) and given name (нэр), asked for separately at registration (owner, 2026-10-14).
-- Nullable: accounts made before this, and companies, have none.
ALTER TABLE users ADD COLUMN last_name VARCHAR(60);
ALTER TABLE users ADD COLUMN first_name VARCHAR(60);
