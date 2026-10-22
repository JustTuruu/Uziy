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
| 10 | **Medium** | Payouts of 0.0000001 ₮ / fractions accepted | `MinimumPayoutRule`: whole ₮, at least 5,000 (1,000 until 2026-10-21) |
| 11 | **Medium** | Stack traces in error responses (devtools default on a dev machine); 5xx messages could carry SQL | `SafeErrorAttributes` strips traces/exception names everywhere and masks 5xx messages; `include-stacktrace: never` |
| 12 | **Medium** | No cap on request size | `RequestSizeLimitFilter` (256 KB → 413) |
| 13 | **Critical (prod only)** | The V2 dev seed creates an **admin whose password is `password`** (confirmed by a live login) plus other known accounts; JWT secret / simulated payments / simulated phone verification have dev defaults | `ProductionReadinessCheck`: with `SPRING_PROFILES_ACTIVE=prod` the app **refuses to start** while any of these is true. `application-prod.yml` takes every secret from the environment with no default |

Verified as already safe (kept as tests): role matrix for all 27 protected endpoints × 4 callers, forged /
unsigned / `alg:none` / expired / tampered tokens, cross-company access to campaigns, payments, analytics
(IDOR), other viewers' payouts, SQL-injection strings in every string field and query parameter, password
hashes never in a response, CORS (foreign origin gets nothing), actuator (only `health`, no details),
`TRACE` refused, double reward, parallel reward and last-budget races, role/balance mass-assignment on
registration.

## Second audit (2026-10-22) — fixed

| # | Severity | Problem found | Fix |
|---|---|---|---|
| 14 | **High** | A password reset loaded the account, asked verify.mn, then saved it back: a payout made in between was undone (old balance written back) | `UserRepository.trySetPassword` — one UPDATE of the hash only; `UserAdminServiceImpl.verify` likewise (`markVerified`) |
| 15 | **High** | Old tokens kept working after a password reset (lost phone, leaked token) | `users.credentials_changed_at` (V16); `JwtAuthFilter` refuses tokens issued before it |
| 16 | **High (local)** | Postgres and pgAdmin (no login) published on 0.0.0.0; the Docker backend used the committed dev JWT secret, so anyone on the Wi-Fi could read all data or forge an admin token | DB + pgAdmin bound to 127.0.0.1; random `JWT_SECRET` in `backend/.env` (8080 stays on the LAN for the phone) |
| 17 | **High** | Panels sent no security headers (admin panel could be framed; no CSP) | `@uziy/ui/security-headers` in all three Next apps: CSP, `frame-ancestors 'none'`, X-Frame-Options, nosniff, Referrer-Policy, HSTS (prod) |
| 18 | **High** | App: JWT keychain item could go into iCloud backups / another phone; Android backups on; release could talk plain http; debug log printed passwords/bank numbers; any URL scheme from the server opened | `appSecureStorage` (this-device-only, encrypted prefs), `allowBackup=false`, https required in release, redacted debug log + `debugLog`, `smsLaunchUri` (sms: only), MoneyMemory cleared on logout, no keyboard learning on bank fields |
| 19 | Medium | 37 Cyrillic letters (over BCrypt's 72 bytes) → 500; login body without phone → 500 | `@BcryptSafe`, `@NotNull` |
| 20 | Medium | Minimum age only enforced by the app | `ViewerAgeRule` (13+, real date) in registration |
| 21 | Medium | A yes to an old consent wording was still counted in statistics | `CONSENTING` also matches `CURRENT_VERSION` |
| 22 | Low | CSV export did not neutralise a leading Tab/CR | added to `SegmentsCsv` |
| 23 | Low | Logs carried a phone (duplicate-key detail) and payout push text | constraint name only; push log = type + count |
| 24 | Bug | Cover uploads over 256 KB were refused (413) | multipart limit 6 MB in `RequestSizeLimitFilter` |

## To do before going live (needs you)

1. **Create the environment** (`SPRING_PROFILES_ACTIVE=prod`): `JWT_SECRET` (random, ≥ 64 chars),
   `DB_URL`/`DB_USER`/`DB_PASSWORD`, `CORS_ALLOWED_ORIGINS` (the real panel URLs),
   `PHONE_VERIFICATION_PROVIDER=verifymn` + `VERIFY_MN_API_KEY` (verify.mn Developer Console),
   `PAYMENTS_SIMULATED=false`. The app will list anything still unsafe when it refuses to start.
2. **Use a fresh production database** — never one that ran the dev seed — and create the first admin by
   hand (`UPDATE users SET role='ADMIN' …`), with a strong password. Delete the seed accounts if any exist.
3. **verify.mn in production** (`PHONE_VERIFICATION_PROVIDER=verifymn` + key) — registration and password reset both
   prove the phone through it (the old `OtpSender` path was removed on 2026-10-14).
4. **A real payment gateway** (QPay) — until then paying a campaign answers 503.
5. **TLS** at the proxy (HSTS header there); `server.forward-headers-strategy=framework` is already set in
   the prod profile so client IPs/HTTPS are read from the proxy.
6. Back up Postgres; restrict its network access to the backend only.

## Open risks (not fixed — decisions or larger work)

* **Rewards can be scripted.** The server cannot know a viewer really watched; a bot with a valid account
  can submit correct answers instantly and collect every reward it is targeted for. Mitigation to build:
  a server-issued *view session* (`POST /viewer/campaigns/{id}/start` stores a timestamp; submit is refused
  until the video's duration has passed), plus per-viewer daily caps and device checks. Needs an app change.
* **Rate limiting is thin.** Only login (per phone) and phone checks (per phone: 60 s cool-down, 5 per hour) are limited. Add per-IP limits at the
  gateway (Cloudflare / nginx) for login, registration and password reset; the in-memory login lock is per instance and
  lets an attacker lock a *known* phone for 15 min (a nuisance, not a breach).
* ~~Open company registration~~ — closed 2026-10-22: only the admin creates companies (`POST /admin/companies`).
* **Tokens**: 24 h, no refresh, no revocation list; the web panels keep the JWT in `localStorage` (XSS would
  steal it). Consider shorter tokens + httpOnly cookies. Admins verify the phone at every login since 2026-10-22.
* **Money is `DOUBLE PRECISION`** (as the spec chose). Whole-₮ rules keep it exact today; move to `NUMERIC`
  before any audit-grade accounting.
* No account-deletion / data-export endpoint (the old privacy text that promised 30-day deletion was removed).
* Dependency vulnerability scan (`dependency-check`/Dependabot) was not run — enable it in CI.
* **(2026-10-22 audit, decisions pending)** company registration needs no phone proof (squats a viewer's number,
  BCrypt CPU cost) · `/auth/phone-verifications` and login reveal which numbers are registered and are limited per
  phone only (per-IP limits at the gateway; admin 2FA or IP allow-list) · `LoginAttemptLimiter` map can be grown
  cheaply (use Caffeine) · company analytics: option totals have no minimum, so a hidden segment = total − the
  shown one; audience slices ("Говь-Сүмбэр: 1") have no minimum; targeting can be one age + one aimag · insights:
  nested filters can be subtracted (allow one dimension or add noise before any buyer access) · admin payout history
  shows full account numbers forever and admin reads of users/payouts are not in `data_access_log` · dropped
  `national_id` values stay in the table file until `VACUUM FULL payout_requests` · no retention/deletion
  (phone_verifications, answers, access log; free-text answers are stored but shown to nobody) · public cover images
  of unapproved campaigns · app on iOS keeps a keychain token after uninstall (needs a non-keychain marker) ·
  backend connects as the Postgres superuser · minimum password length 6 · panel JWT in localStorage (now under a CSP).

