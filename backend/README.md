# Uziy backend

Spring Boot 4 + Kotlin + PostgreSQL. Implements the API consumed by
`viewer_app/` (Flutter) and `admin_panel/` (Next.js).

## Prerequisites

- JDK 17+ (Homebrew `openjdk@17` works)
- Docker (for the local Postgres)

## Run

```bash
# 1. Start Postgres in the background
docker compose up -d postgres

# 2. Start the API (Flyway migrations + seed run automatically on first boot)
./gradlew bootRun
```

The API listens on http://localhost:8080.

## Environment variables

| Var             | Default                                                     |
| --------------- | ----------------------------------------------------------- |
| `PORT`          | `8080`                                                      |
| `DB_URL`        | `jdbc:postgresql://localhost:5432/uziy`                     |
| `DB_USER`       | `uziy`                                                      |
| `DB_PASSWORD`   | `uziy_dev`                                                  |
| `JWT_SECRET`    | dev-only string; **override in prod, 256 bits minimum**     |
| `PAYMENTS_SIMULATED` | `true` — the company's "Төлөх" button marks a campaign paid instantly (no money moves). Set `false` in prod until QPay is wired; `POST /company/campaigns/{id}/pay` then answers 503. |

## Endpoints

| Method + Path                                    | Role      | Purpose                                          |
| ------------------------------------------------ | --------- | ------------------------------------------------ |
| `POST /auth/login`                               | anon      | Return JWT + `Me`                                |
| `POST /auth/register/viewer`                     | anon      | Create viewer + return JWT                       |
| `POST /auth/register/company`                    | anon      | Create company + return JWT                      |
| `GET  /viewer/me`                                | VIEWER    | Current user profile                             |
| `GET  /viewer/feed`                              | VIEWER    | Home feed (spec §4B targeting SQL)               |
| `GET  /viewer/campaigns/{id}/questions`          | VIEWER    | Survey for a campaign                            |
| `POST /viewer/campaigns/{id}/submit`             | VIEWER    | **Atomic reward transaction (spec §4C)**         |
| `POST /viewer/payouts`                           | VIEWER    | Request cash-out (balance reserved)              |
| `GET  /viewer/payouts`                           | VIEWER    | Own cash-out history                             |
| `GET  /platform-settings`                        | anon      | `{commissionPercent, minRewardPerViewer, updatedAt}` |
| `GET  /company/campaigns`                        | COMPANY   | List own campaigns                               |
| `POST /company/campaigns`                        | COMPANY   | Create campaign + survey questions → `AWAITING_PAYMENT` (body: `totalBudget` + exactly one of `targetViewers` / `rewardPerUser`; server prices it) |
| `GET  /company/campaigns/{id}`                   | COMPANY   | Own-campaign detail                              |
| `POST /company/campaigns/{id}/pay`               | COMPANY   | Pay one campaign → `PENDING` (moderation); returns `{campaign, payment}` |
| `GET  /company/payments`                         | COMPANY   | Own campaign payments, newest first              |
| `PATCH /company/campaigns/{id}/status`           | COMPANY   | ACTIVE⇄PAUSED, ACTIVE/PAUSED→COMPLETED only (else 409) |
| `GET  /admin/stats`                              | ADMIN     | Platform counters                                |
| `PATCH /admin/platform-settings`                 | ADMIN     | Set commission % (1–90) + minimum reward per viewer |
| `GET  /admin/users`                              | ADMIN     | All users                                        |
| `PATCH /admin/users/{id}/verify`                 | ADMIN     | Set `is_verified = TRUE` (spec §4A)              |
| `GET  /admin/campaigns?status=PENDING`           | ADMIN     | Moderation queue                                 |
| `PATCH /admin/campaigns/{id}/moderate`           | ADMIN     | Approve/reject a paid (`PENDING`) campaign       |
| `GET  /admin/payouts`                            | ADMIN     | Pending cash-out requests                        |
| `PATCH /admin/payouts/{id}/decision`             | ADMIN     | Approve/reject; approving 1st payout ⇒ verified  |

## Development notes

- **Migrations** live in `src/main/resources/db/migration/` and run
  automatically on startup via Flyway. Add new migrations as `V<N>__desc.sql`.
- The **atomic reward transaction** (spec §4C) lives in
  `viewer/RewardService.kt` (`RewardServiceImpl.submitSurvey`). It runs at `SERIALIZABLE` isolation
  and uses `CampaignRepository.tryDecrementBudget` for a conditional update
  that races safely with concurrent viewers.
- Dev-seeded users all have password `password` (BCrypt cost 10, hash
  hard-coded in `V2__seed_dev_data.sql`). Do NOT ship that migration to prod.
- **Pricing** lives in `pricing/CampaignPricing.kt` (integer ₮ math, mirrored
  by `admin_panel/lib/pricing.ts` — keep the two and their test vectors in
  sync). Budget B and either viewers N (C = ⌊B/N⌋, R = ⌊C·(100−c)/100⌋) or
  reward R (C = ⌈R·100/(100−c)⌉, N = ⌊B/C⌋); the company is charged
  P = C·N ≤ B. The commission c and the minimum reward come from
  `platform_settings` (Super Admin); targeting does not affect price.
- **Campaign lifecycle**: `AWAITING_PAYMENT` → pay → `PENDING` → admin
  moderates → `ACTIVE`/`REJECTED`; the company can then pause/resume/complete.
  The pay step is a conditional UPDATE plus the partial unique index
  `ux_campaign_payments_one_paid`, so a campaign is paid at most once.
- **Never edit an applied migration** (Flyway validates checksums on boot).
  V5 is already applied on the local dev DB.
- No video upload / R2 integration yet. `POST /company/campaigns` accepts a
  `videoUrl` string; the FFmpeg worker is a separate future service.

## Wipe + restart

```bash
docker compose down -v && docker compose up -d postgres
./gradlew bootRun
```

## Browse the database (pgAdmin)

`docker compose up -d pgadmin` → http://localhost:5050 (no login). The
"Uziy (local)" server is pre-registered; when it asks for a password use
`uziy_dev`. Tables: Servers → Uziy (local) → Databases → uziy → Schemas →
public → Tables → right-click → View/Edit Data. Dev only.
