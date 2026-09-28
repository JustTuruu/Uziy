-- Survey-only campaigns + platform-wide admin-configurable pricing.
--
-- The product now supports a second campaign shape where a company just
-- wants aggregate opinion data — no video to show, viewers answer the
-- survey directly. Pricing for this mode is set centrally by the Super
-- Admin (viewers don't watch anything, so the natural "cost per view"
-- model doesn't apply); companies pay whatever the platform currently
-- charges per completed survey.

-- --- campaigns ---------------------------------------------------------

ALTER TABLE campaigns
    ADD COLUMN has_video BOOLEAN NOT NULL DEFAULT TRUE;

-- Survey-only campaigns have no video → allow duration 0. The old
-- CHECK constraint required duration_seconds >= 5. Replace it.
ALTER TABLE campaigns
    DROP CONSTRAINT IF EXISTS campaigns_duration_seconds_check;

ALTER TABLE campaigns
    ADD CONSTRAINT campaigns_duration_seconds_check
        CHECK (
            (has_video = TRUE  AND duration_seconds BETWEEN 5 AND 180)
         OR (has_video = FALSE AND duration_seconds = 0)
        );

-- --- platform_settings (singleton) -------------------------------------

CREATE TABLE platform_settings (
    id                             INT PRIMARY KEY DEFAULT 1,
    survey_only_cost_per_response  DOUBLE PRECISION NOT NULL DEFAULT 400
                                    CHECK (survey_only_cost_per_response > 0),
    survey_only_reward_per_user    DOUBLE PRECISION NOT NULL DEFAULT 250
                                    CHECK (survey_only_reward_per_user > 0),
    updated_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by                     BIGINT REFERENCES users(id),
    CONSTRAINT platform_settings_singleton CHECK (id = 1),
    CONSTRAINT survey_only_reward_lt_cost
        CHECK (survey_only_reward_per_user < survey_only_cost_per_response)
);

-- The single row. Row-count invariant is enforced by the CHECK above
-- combined with the primary-key uniqueness.
INSERT INTO platform_settings (id) VALUES (1);
