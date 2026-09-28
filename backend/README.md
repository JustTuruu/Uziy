# Zoos backend

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
| `DB_URL`        | `jdbc:postgresql://localhost:5432/zoos`                     |
| `DB_USER`       | `zoos`                                                      |
| `DB_PASSWORD`   | `zoos_dev`                                                  |
| `JWT_SECRET`    | dev-only string; **override in prod, 256 bits minimum**     |

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
| `GET  /company/campaigns`                        | COMPANY   | List own campaigns                               |
| `POST /company/campaigns`                        | COMPANY   | Create campaign + survey questions               |
| `GET  /company/campaigns/{id}`                   | COMPANY   | Own-campaign detail                              |
| `PATCH /company/campaigns/{id}/status`           | COMPANY   | Pause/resume/end                                 |
| `GET  /admin/stats`                              | ADMIN     | Platform counters                                |
| `GET  /admin/users`                              | ADMIN     | All users                                        |
| `PATCH /admin/users/{id}/verify`                 | ADMIN     | Set `is_verified = TRUE` (spec §4A)              |
| `GET  /admin/campaigns?status=PENDING`           | ADMIN     | Moderation queue                                 |
| `PATCH /admin/campaigns/{id}/moderate`           | ADMIN     | Approve/reject a submitted campaign              |
| `GET  /admin/payouts`                            | ADMIN     | Pending cash-out requests                        |
| `PATCH /admin/payouts/{id}/decision`             | ADMIN     | Approve/reject; approving 1st payout ⇒ verified  |

## Development notes

- **Migrations** live in `src/main/resources/db/migration/` and run
  automatically on startup via Flyway. Add new migrations as `V<N>__desc.sql`.
- The **atomic reward transaction** (spec §4C) lives in
  `viewer/ViewerController.kt::submit`. It runs at `SERIALIZABLE` isolation
  and uses `CampaignRepository.tryDecrementBudget` for a conditional update
  that races safely with concurrent viewers.
- Dev-seeded users all have password `password` (BCrypt cost 10, hash
  hard-coded in `V2__seed_dev_data.sql`). Do NOT ship that migration to prod.
- No video upload / R2 integration yet. `POST /company/campaigns` accepts a
  `videoUrl` string; the FFmpeg worker is a separate future service.

## Wipe + restart

```bash
docker compose down -v && docker compose up -d postgres
./gradlew bootRun
```
