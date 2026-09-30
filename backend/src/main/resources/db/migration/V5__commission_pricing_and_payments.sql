-- Commission-based pricing + per-campaign payment.
--
-- Old model: the company picked a cost-per-view (video) or paid an
-- admin-fixed price per survey response, and targeting precision moved the
-- price. New model (both video and survey-only campaigns):
--
--   * the company enters a total budget B and EITHER the number of viewers
--     N OR the reward per viewer R; the other one is derived
--     (see mn.uziy.backend.pricing.CampaignPricing / admin_panel/lib/pricing.ts);
--   * the platform keeps a Super-Admin-set percentage of every viewer's cost;
--   * there is no pre-funded company balance — each campaign is paid for on
--     its own (AWAITING_PAYMENT → PENDING) before it reaches moderation.

-- --- campaigns: new lifecycle state ------------------------------------

-- V1 declared the status CHECK inline, so Postgres named it
-- <table>_<column>_check.
ALTER TABLE campaigns
    DROP CONSTRAINT IF EXISTS campaigns_status_check;

ALTER TABLE campaigns
    ADD CONSTRAINT campaigns_status_check
        CHECK (status IN ('AWAITING_PAYMENT','PENDING','ACTIVE','PAUSED','COMPLETED','REJECTED'));

-- Anything inserted without an explicit status must NOT skip payment.
ALTER TABLE campaigns
    ALTER COLUMN status SET DEFAULT 'AWAITING_PAYMENT';

-- --- campaigns: pricing snapshot + payment timestamp -------------------

ALTER TABLE campaigns
    ADD COLUMN target_viewers INT NULL
        CONSTRAINT campaigns_target_viewers_check CHECK (target_viewers > 0);

-- Backfill: how many views the existing budget buys at the stored price.
-- GREATEST(1, …) keeps the CHECK happy for budgets below one view;
-- LEAST(…) guards the INT range.
UPDATE campaigns
   SET target_viewers = GREATEST(1, LEAST(2147483647, FLOOR(total_budget / cost_per_view)))::INT;

-- Rate used when the campaign was priced. NULL for legacy rows: they were
-- priced by the old cost-per-view model, not by a commission percentage.
ALTER TABLE campaigns
    ADD COLUMN commission_percent INT NULL
        CONSTRAINT campaigns_commission_percent_check CHECK (commission_percent BETWEEN 1 AND 90);

ALTER TABLE campaigns
    ADD COLUMN paid_at TIMESTAMPTZ NULL;

-- --- platform_settings: commission model replaces fixed survey pricing ---

ALTER TABLE platform_settings
    ADD COLUMN commission_percent INT NOT NULL DEFAULT 30
        CONSTRAINT platform_settings_commission_percent_check
            CHECK (commission_percent BETWEEN 1 AND 90);

ALTER TABLE platform_settings
    ADD COLUMN min_reward_per_viewer INT NOT NULL DEFAULT 100
        CONSTRAINT platform_settings_min_reward_per_viewer_check
            CHECK (min_reward_per_viewer >= 1);

ALTER TABLE platform_settings
    DROP CONSTRAINT IF EXISTS survey_only_reward_lt_cost;

ALTER TABLE platform_settings
    DROP COLUMN survey_only_cost_per_response,
    DROP COLUMN survey_only_reward_per_user;

-- --- campaign_payments --------------------------------------------------

CREATE TABLE campaign_payments (
    id           BIGSERIAL        PRIMARY KEY,
    campaign_id  BIGINT           NOT NULL REFERENCES campaigns(id),
    company_id   BIGINT           NOT NULL REFERENCES users(id),
    amount       DOUBLE PRECISION NOT NULL CHECK (amount > 0),
    provider     VARCHAR(20)      NOT NULL
                  CHECK (provider IN ('SIMULATED','QPAY','BANK_TRANSFER')),
    status       VARCHAR(20)      NOT NULL
                  CHECK (status IN ('PAID','FAILED','REFUNDED')),
    reference    VARCHAR(40)      NOT NULL UNIQUE,
    created_at   TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    paid_at      TIMESTAMPTZ      NULL
);

-- Backstop behind the conditional status UPDATE: a campaign can be paid
-- for at most once.
CREATE UNIQUE INDEX ux_campaign_payments_one_paid
    ON campaign_payments(campaign_id)
    WHERE status = 'PAID';

CREATE INDEX idx_campaign_payments_company ON campaign_payments(company_id);
