-- Default commissions per campaign kind (owner, 2026-10-30): commission_percent stays the video campaigns' default,
-- survey-only campaigns get their own, starting at today's value. The admin sets each campaign's own percentage when
-- approving it (campaigns.commission_percent), which re-splits what the company paid.
ALTER TABLE platform_settings
    ADD COLUMN survey_commission_percent INT NOT NULL DEFAULT 30
        CONSTRAINT platform_settings_survey_commission_percent_check
            CHECK (survey_commission_percent BETWEEN 1 AND 90);

UPDATE platform_settings SET survey_commission_percent = commission_percent;
