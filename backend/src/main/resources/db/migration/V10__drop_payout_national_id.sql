-- The payout form no longer asks for the national ID (owner, 2026-10-14). The values already collected are
-- deleted with the column: personal data that is no longer used is not kept.
ALTER TABLE payout_requests DROP COLUMN national_id;
