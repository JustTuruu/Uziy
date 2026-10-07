# Targeted Rewarded Video Platform — Original Specification

> This file preserves the original project brief verbatim (as provided by the user)
> so future sessions have a canonical source of truth.

## 1. Project Purpose & Business Model

- **Name:** Targeted Rewarded Video Platform (Зорилтот урамшуулалт видео систем)
- **Business logic:** Companies pay to deliver 30 sec – 2 min ads to targeted users
  (by age, gender, location). Viewers watch the full video, complete a 2–3 question
  survey, and receive a portion (e.g. 500–700 ₮) of the company's spend into their
  in-app wallet. The Super Admin oversees the entire process and takes a 30–40%
  commission from each transaction.

## 2. Tech Stack

### Front-End
- **Viewer app + Company app:** Flutter (Dart) — single codebase for iOS + Android.
- **Super Admin dashboard:** React (or Flutter Web) — desktop-focused for finance /
  video moderation on a large screen.

### Back-End & Compute
- **Core backend:** Spring Boot (Java/Kotlin) — responsible for financial safety and
  atomic transactions.
- **Database:** PostgreSQL — user balance, history, survey data.
- **Video transcoding:** Separate small server running FFmpeg, or AWS MediaConvert.

### Cloud & Storage
- **Storage:** Cloudflare R2 — no egress fees for video streaming (~99% cost
  savings vs S3).
- **Hosting:** DigitalOcean or Hetzner ($6–$12/mo VPS).

## 3. Database Schema

```
[Users (Viewer, Company, Admin)]
    │
    ├──1:N──> [Campaigns / Videos (video + target config)]
    │              │
    │              └──1:N──> [Survey Questions (2–3 questions)]
    │
    └──1:N──> [Payout Requests (withdrawal requests)]
```

### `users`
```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL, -- 'VIEWER', 'COMPANY', 'ADMIN'
    gender VARCHAR(10),         -- 'MALE', 'FEMALE'
    birth_date DATE,            -- used to compute age
    city VARCHAR(50),           -- location filter (Ulaanbaatar, etc.)
    district VARCHAR(50),
    balance DOUBLE PRECISION DEFAULT 0.0,
    is_verified BOOLEAN DEFAULT FALSE, -- verified on first payout
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### `campaigns`
```sql
CREATE TABLE campaigns (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT REFERENCES users(id),
    video_url VARCHAR(500) NOT NULL,           -- .m3u8 on Cloudflare R2
    target_gender VARCHAR(10) DEFAULT 'ALL',
    min_age INT DEFAULT 0,
    max_age INT DEFAULT 100,
    target_city VARCHAR(50) DEFAULT 'ALL',
    total_budget DOUBLE PRECISION NOT NULL,
    remaining_budget DOUBLE PRECISION NOT NULL,
    cost_per_view DOUBLE PRECISION NOT NULL,   -- rises with targeting precision
    reward_per_user DOUBLE PRECISION NOT NULL, -- amount received by viewer
    status VARCHAR(20) DEFAULT 'ACTIVE'        -- ACTIVE / PAUSED / COMPLETED
);
```

## 4. Core Algorithms

### A. Incentivized Profiling
On registration, prominently display this message in Flutter:

> 💡 "Та өөрийн нас, хүйс, байршлыг үнэн зөв оруулснаар өөрт тохирсон илүү олон,
> илүү өндөр дүнтэй видео судалгаануудыг хүлээн авч, урамшууллаа нэмэгдүүлэх боломжтой
> болно."

When the user requests their **first payout**, the Admin verifies that the bank
account name + national ID matches the profile data. If it matches, the user is
marked `is_verified = TRUE`. This prevents false profile data at the payout gate.

### B. Home Feed Query
When the viewer opens the app, show only videos matching age/gender/city that the
user has NOT already seen:

```sql
SELECT c.* FROM campaigns c
WHERE (c.target_gender = 'ALL' OR c.target_gender = :user_gender)
  AND (:user_age BETWEEN c.min_age AND c.max_age)
  AND (c.target_city = 'ALL' OR c.target_city = :user_city)
  AND c.remaining_budget >= c.cost_per_view
  AND c.status = 'ACTIVE'
  AND c.id NOT IN (SELECT video_id FROM view_history WHERE user_id = :user_id);
```

### C. Financial Safety (Atomic Transaction)
When the user finishes the survey, run these three steps inside a single DB
transaction — if any fails, everything rolls back:

1. Insert a row into `view_history` (so the same video is never rewarded twice).
2. Deduct `cost_per_view` from `campaigns.remaining_budget`.
3. Add `reward_per_user` to `users.balance`.

## 5. HLS Streaming Pipeline

When a company uploads an .mp4, a separate "Video Worker" runs FFmpeg:

1. Transcode the video into 3 quality levels (480p / 720p / 1080p).
2. Split into 2–3 second `.ts` chunks and generate an `.m3u8` manifest.
3. Upload everything to Cloudflare R2. Flutter can then stream it with instant
   start (TikTok-style playback).

## 6. Company-Facing Tools

- Cost calculator: given a budget and a per-user reward, show how many users can
  be reached.
- Age-bucket targeting (with pricing that scales by precision).
- Standard survey templates (10–30 question option) so companies can buy the
  resulting survey data on demand.

---

## Placeholder credential noted in original brief

`CloudFront Dev Public Key ID: K1ABCDEFGHIJ12`

This looks like a placeholder (sequential letters — not a real key). It is
recorded here only as-is; do not treat it as a real secret. Replace with a real
key ID in an untracked `.env` file when the CDN is provisioned.
