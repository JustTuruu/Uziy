# Production checklist & security audit

Result of a full audit of every API (2026-10-07): a security test suite
(`backend/src/test/java/mn/uziy/backend/security/`, ~170 checks over a real Postgres and the real
filter chain) plus black-box `curl` probes against a running server. Everything marked **Fixed** has a
regression test; **Open** items need a decision or work outside the backend.

## Fixed in this audit

| # | Severity | Problem found | Fix |
|---|---|---|---|
| 1 | **Critical** | 6 parallel payout requests against a 1,000 ₮ balance **all succeeded** (6,000 ₮ requested): read-modify-write on the balance | Balance is only moved by atomic SQL (`tryDeductBalance` = `balance - x WHERE balance >= x`, `addBalance`); `@DynamicUpdate` on `UserEntity` so a stale entity can never write the balance back |
| 2 | **Critical** | A payout could be decided twice at once (double refund) | `PayoutRepository.tryClaim`: one conditional UPDATE out of `PENDING` |
| 3 | **High** | A reward was paid for *any* answers: unrelated question ids, blank answers, options that do not exist, no required question answered | `AnswerValidator` — every answer must be for this campaign's questions, once, valid JSON of the right shape and size, within the options; all required questions answered |
| 4 | **High** | Any viewer could collect the reward of any campaign id, outside its targeting (gender/age/city) | `CampaignTargeting.matches` checked in the reward transaction (answers 404, like a missing campaign) |
| 5 | **High** | Unreleased (PENDING / paused / finished) surveys' questions readable by every viewer | `/viewer/campaigns/{id}/questions` only for ACTIVE campaigns |
| 6 | **High** | A token stayed valid after its account was deleted or its role changed (e.g. a demoted admin kept admin for 24 h); deleted user → 500 | `JwtAuthFilter` checks the account still exists with the same role on every request |
| 7 | **High** | No limit on password guessing | `LoginAttemptLimiter`: 5 wrong passwords → 15 min lock (429), also for unknown phones |
| 8 | **Medium** | The reward's SERIALIZABLE transaction surfaced races as HTTP 500 | `RetryingRewardService` (Decorator) retries, then answers 409 |
| 9 | **Medium** | Over-long text, invalid JSON answers, missing ids → database errors → 500 with SQL in the message | field size limits, validation, `NotFoundException`s, a handler for integrity/concurrency errors |
| 10 | **Medium** | Payouts of 0.0000001 ₮ / fractions accepted | `MinimumPayoutRule`: whole ₮, at least 1,000 |
| 11 | **Medium** | Stack traces in error responses (devtools default on a dev machine); 5xx messages could carry SQL | `SafeErrorAttributes` strips traces/exception names everywhere and masks 5xx messages; `include-stacktrace: never` |
| 12 | **Medium** | No cap on request size | `RequestSizeLimitFilter` (256 KB → 413) |
| 13 | **Critical (prod only)** | The V2 dev seed creates an **admin whose password is `password`** (confirmed by a live login) plus other known accounts; JWT secret / simulated payments / logging OTP have dev defaults | `ProductionReadinessCheck`: with `SPRING_PROFILES_ACTIVE=prod` the app **refuses to start** while any of these is true. `application-prod.yml` takes every secret from the environment with no default |

Verified as already safe (kept as tests): role matrix for all 27 protected endpoints × 4 callers, forged /
unsigned / `alg:none` / expired / tampered tokens, cross-company access to campaigns, payments, analytics
(IDOR), other viewers' payouts, SQL-injection strings in every string field and query parameter, password
hashes never in a response, CORS (foreign origin gets nothing), actuator (only `health`, no details),
`TRACE` refused, double reward, parallel reward and last-budget races, role/balance mass-assignment on
registration.

## To do before going live (needs you)

1. **Create the environment** (`SPRING_PROFILES_ACTIVE=prod`): `JWT_SECRET` (random, ≥ 64 chars),
   `DB_URL`/`DB_USER`/`DB_PASSWORD`, `CORS_ALLOWED_ORIGINS` (the real panel URLs), `OTP_SENDER`,
   `PHONE_VERIFICATION_PROVIDER=verifymn` + `VERIFY_MN_API_KEY` (verify.mn Developer Console),
   `PAYMENTS_SIMULATED=false`. The app will list anything still unsafe when it refuses to start.
2. **Use a fresh production database** — never one that ran the dev seed — and create the first admin by
   hand (`UPDATE users SET role='ADMIN' …`), with a strong password. Delete the seed accounts if any exist.
3. **A real SMS sender** (`OtpSender` implementation) for password-reset codes — until then nobody can
   reset a password in production. (Registration no longer needs it: it uses verify.mn.)
4. **A real payment gateway** (QPay) — until then paying a campaign answers 503.
5. **TLS** at the proxy (HSTS header there); `server.forward-headers-strategy=framework` is already set in
   the prod profile so client IPs/HTTPS are read from the proxy.
6. Back up Postgres; restrict its network access to the backend only.

## Open risks (not fixed — decisions or larger work)

* **Rewards can be scripted.** The server cannot know a viewer really watched; a bot with a valid account
  can submit correct answers instantly and collect every reward it is targeted for. Mitigation to build:
  a server-issued *view session* (`POST /viewer/campaigns/{id}/start` stores a timestamp; submit is refused
  until the video's duration has passed), plus per-viewer daily caps and device checks. Needs an app change.
* **Rate limiting is thin.** Only login (per phone) and OTP (per phone) are limited. Add per-IP limits at the
  gateway (Cloudflare / nginx) for login, registration and OTP; the in-memory login lock is per instance and
  lets an attacker lock a *known* phone for 15 min (a nuisance, not a breach).
* **Open company registration** (`/auth/register/company`) has no verification — spam accounts are possible.
* **Tokens**: 24 h, no refresh, no revocation list; the web panels keep the JWT in `localStorage` (XSS would
  steal it). Consider shorter tokens + httpOnly cookies. No 2FA for admins.
* **Money is `DOUBLE PRECISION`** (as the spec chose). Whole-₮ rules keep it exact today; move to `NUMERIC`
  before any audit-grade accounting.
* No account-deletion / data-export endpoint (the old privacy text that promised 30-day deletion was removed).
* Dependency vulnerability scan (`dependency-check`/Dependabot) was not run — enable it in CI.
