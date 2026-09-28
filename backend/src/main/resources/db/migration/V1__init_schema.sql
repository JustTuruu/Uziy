-- Uziy initial schema. Mirrors docs/SPEC.md §3.
-- All timestamps are stored in UTC. Money is DOUBLE PRECISION as per spec —
-- switch to NUMERIC(14,2) later if audit-grade precision becomes a requirement.

CREATE TABLE users (
    id             BIGSERIAL PRIMARY KEY,
    phone_number   VARCHAR(15)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    role           VARCHAR(20)  NOT NULL CHECK (role IN ('VIEWER', 'COMPANY', 'ADMIN')),
    -- Viewer profile (nullable for COMPANY / ADMIN accounts):
    gender         VARCHAR(10)  CHECK (gender IN ('MALE', 'FEMALE')),
    birth_date     DATE,
    city           VARCHAR(50),
    district       VARCHAR(50),
    balance        DOUBLE PRECISION NOT NULL DEFAULT 0.0 CHECK (balance >= 0),
    is_verified    BOOLEAN      NOT NULL DEFAULT FALSE,
    -- Company profile (nullable for VIEWER / ADMIN):
    company_name   VARCHAR(120),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_targeting ON users(gender, city) WHERE role = 'VIEWER';

CREATE TABLE campaigns (
    id                BIGSERIAL PRIMARY KEY,
    company_id        BIGINT      NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    title             VARCHAR(200) NOT NULL,
    video_url         VARCHAR(500) NOT NULL DEFAULT '',
    thumbnail_url     VARCHAR(500),
    duration_seconds  INT         NOT NULL CHECK (duration_seconds BETWEEN 5 AND 180),
    target_gender     VARCHAR(10) NOT NULL DEFAULT 'ALL' CHECK (target_gender IN ('ALL', 'MALE', 'FEMALE')),
    min_age           INT         NOT NULL DEFAULT 0    CHECK (min_age  BETWEEN 0 AND 120),
    max_age           INT         NOT NULL DEFAULT 100  CHECK (max_age BETWEEN 0 AND 120),
    target_city       VARCHAR(50) NOT NULL DEFAULT 'ALL',
    total_budget      DOUBLE PRECISION NOT NULL CHECK (total_budget > 0),
    remaining_budget  DOUBLE PRECISION NOT NULL CHECK (remaining_budget >= 0),
    cost_per_view     DOUBLE PRECISION NOT NULL CHECK (cost_per_view > 0),
    reward_per_user   DOUBLE PRECISION NOT NULL CHECK (reward_per_user > 0),
    status            VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING','ACTIVE','PAUSED','COMPLETED','REJECTED')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT age_range CHECK (min_age <= max_age),
    CONSTRAINT reward_lt_cost CHECK (reward_per_user < cost_per_view)
);

CREATE INDEX idx_campaigns_status  ON campaigns(status);
CREATE INDEX idx_campaigns_targeting
    ON campaigns(status, target_gender, target_city, min_age, max_age)
    WHERE status = 'ACTIVE';
CREATE INDEX idx_campaigns_company ON campaigns(company_id);

CREATE TABLE survey_questions (
    id            BIGSERIAL PRIMARY KEY,
    campaign_id   BIGINT       NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    position      INT          NOT NULL,
    prompt        TEXT         NOT NULL,
    q_type        VARCHAR(20)  NOT NULL CHECK (q_type IN ('SINGLE_CHOICE','MULTI_CHOICE','TEXT')),
    options_json  JSONB        NOT NULL DEFAULT '[]'::jsonb,
    required      BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (campaign_id, position)
);

CREATE INDEX idx_questions_campaign ON survey_questions(campaign_id);

-- One row per (user, campaign) — GUARANTEES a viewer can't be rewarded twice
-- for the same video. This uniqueness is load-bearing: the atomic reward
-- transaction (spec §4C) relies on the INSERT here failing if the pair
-- already exists.
CREATE TABLE view_history (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    campaign_id   BIGINT      NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    reward_paid   DOUBLE PRECISION NOT NULL,
    watched_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, campaign_id)
);

CREATE INDEX idx_history_user ON view_history(user_id);

CREATE TABLE survey_responses (
    id            BIGSERIAL PRIMARY KEY,
    view_id       BIGINT       NOT NULL REFERENCES view_history(id) ON DELETE CASCADE,
    question_id   BIGINT       NOT NULL REFERENCES survey_questions(id) ON DELETE CASCADE,
    answer_json   JSONB        NOT NULL, -- string | string[] | object
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (view_id, question_id)
);

CREATE INDEX idx_responses_question ON survey_responses(question_id);

CREATE TABLE payout_requests (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount          DOUBLE PRECISION NOT NULL CHECK (amount > 0),
    bank            VARCHAR(60)  NOT NULL,
    account_number  VARCHAR(30)  NOT NULL,
    account_name    VARCHAR(120) NOT NULL,
    national_id     VARCHAR(20)  NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','APPROVED','REJECTED')),
    is_first_payout BOOLEAN      NOT NULL DEFAULT FALSE,
    reject_reason   VARCHAR(500),
    decided_by      BIGINT       REFERENCES users(id),
    requested_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    decided_at      TIMESTAMPTZ
);

CREATE INDEX idx_payouts_status ON payout_requests(status);
CREATE INDEX idx_payouts_user   ON payout_requests(user_id);
