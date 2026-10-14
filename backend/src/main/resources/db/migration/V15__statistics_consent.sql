-- Anonymous statistics from viewers' answers may only use people who said yes (owner, 2026-10-14; Mongolia's
-- Personal Data Protection Law 2021 requires consent for this purpose). NULL = never asked. Existing viewers stay
-- out of every statistic until they agree in the app.
ALTER TABLE users ADD COLUMN stats_consent VARCHAR(10)
    CHECK (stats_consent IN ('GRANTED', 'DECLINED'));
ALTER TABLE users ADD COLUMN stats_consent_at TIMESTAMPTZ;
-- Which wording of the consent text the viewer saw; a new wording can ask again.
ALTER TABLE users ADD COLUMN stats_consent_version VARCHAR(20);

-- Every look at the statistics is recorded: who, what, when. Rows are never updated or deleted by the app.
CREATE TABLE data_access_log (
    id         BIGSERIAL    PRIMARY KEY,
    admin_id   BIGINT       NOT NULL REFERENCES users(id),
    action     VARCHAR(40)  NOT NULL,
    detail     VARCHAR(500) NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_data_access_log_created ON data_access_log(created_at DESC);
