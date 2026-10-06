# CLAUDE.md — Handoff for the Next Session

> **Read this file first.** It gives you the full picture of what this project
> is, what's already built, and where to pick up. The original product brief
> lives at `docs/SPEC.md`.

> **Standing rule from the user (2026-09-28):** Whenever you add a
> function, feature, endpoint, or non-trivial piece of logic, you MUST write
> unit tests for it in the same turn — don't wait to be asked. Run them
> before reporting done. Exceptions are only typos, one-line style tweaks,
> and purely cosmetic UI changes — and even then, say so explicitly so the
> user knows the omission was deliberate. Frameworks per surface: Spring →
> JUnit 5 + Mockito + AssertJ (+ `@DataJpaTest` / `@SpringBootTest` /
> Testcontainers for anything touching the DB), Flutter → `flutter_test`, Next.js → whatever the project uses (check
> `package.json`; add Vitest if nothing is wired up yet). See also
> `~/.claude/projects/-Users-justturuu-Documents/memory/feedback_write_tests.md`.

---

## 0. Engineering rules (MANDATORY — user's standing requirements)

These come straight from the project owner. Follow them on EVERY change, in
every surface, without being reminded. If a rule would be violated by what is
asked, say so and propose the compliant way instead of silently bending it.

### 0.1 Rules for all code (frontend + backend + mobile)

1. **Always write unit tests** for every new function, feature, endpoint, hook,
   component, or non-trivial logic — in the same turn — and **run them** before
   reporting done. Bug fix → add a regression test that fails without the fix.
   Only typos, one-line style tweaks and purely cosmetic changes are exempt, and
   you must say explicitly that the omission is deliberate.
2. **Use design patterns deliberately** where they remove duplication or make a
   variation point explicit; name the pattern in a one-line Javadoc/comment
   (`Pattern: Strategy — …`). Do not force a pattern where a plain function is
   clearer (YAGNI), but never copy-paste instead of abstracting. Implemented in
   the backend (keep following them; extend, don't bypass):
   - **Strategy** — `PaymentGateway` (new provider = new `@Component`),
     `PayoutDecisionStrategy` (Approve/Reject), `ModerationStrategy`
     (ApproveCampaign/RejectCampaign). Picked by a **Registry/Factory**:
     `PaymentGatewaySelector`, `PayoutDecisionStrategies`,
     `ModerationStrategyRegistry`.
   - **State** — `CampaignStatus.canTransitionTo(next, CampaignActor)` is the ONE
     source of truth for the campaign lifecycle (SYSTEM pays, ADMIN moderates,
     COMPANY pauses/resumes/completes). Never hand-write status `if/else`.
   - **Observer / domain events** — services publish records implementing
     `DomainEvent` through `DomainEventPublisher` (synchronous, inside the
     transaction): `UserRegistered`, `CampaignCreated`, `CampaignPaid`,
     `CampaignStatusChanged`, `RewardGranted`, `PayoutRequested`,
     `PayoutDecided`. `AuditLogListener` logs each as `audit event=…`. New
     side effects = new `@EventListener`, not edits to the service.
   - **Chain of Responsibility** — `PayoutRule` chain (`PayoutRuleChain`); add a
     validation rule = add a `@Component` rule.
   - **Factory** — `CampaignFactory`, `UserFactory` build entities from requests.
   - **Mapper** — `CampaignMapper`, `PaymentMapper`, `PayoutMapper`,
     `UserMapper`, `AdminCampaignMapper`, `PlatformSettingsMapper`, `MeMapper`,
     `FeedItemMapper`, `QuestionMapper`: services never build response DTOs
     inline.
   - **Facade / Service layer**, **Repository**, **DTO/Value Object** (`record`s,
     e.g. `PricingResult`), **Dependency Injection** (constructor only), and
     **Clock injection** (`java.time.Clock` bean; never call
     `OffsetDateTime.now()` directly in services; tests use `Clock.fixed`).
   Frontend/test patterns: **Composite components** (`Card`+`CardHeader`+
   `CardBody`), **Custom hook** (`useStoredUser()`), **Builder/Factory** for
   test fixtures (`*TestData`, `*TestFixtures`).
3. **Clean code.** Small functions with one reason to change, intention-revealing
   names, no magic numbers/strings (named constants), no dead code or leftover
   files, no commented-out code, comments explain *why* (business rules in the
   KDoc/Javadoc style already used). **DRY**: if two places need the same
   control/logic, create ONE component/function and use it in both.
4. **Do not swap technology** from the agreed stack without asking (see §1).
5. **Keep this file current** whenever you add/rename/delete files or change a
   rule.
6. UI copy is **Cyrillic Mongolian** (short, informal-polite "Та"); currency is
   ₮. Do not switch UI copy to Latin.
7. Report faithfully: if tests fail or something was not run, say so.

### 0.2 Backend rules (Spring Boot 4, **Java 17**, PostgreSQL)

1. **Language is Java 17** (converted from Kotlin on 2026-10-06). No Lombok, no
   new Kotlin. DTOs = `record`s; entities = plain classes with getters/setters;
   "maybe missing" results = `Optional`, never `null`; annotate genuinely
   nullable params/components with `org.jspecify.annotations.Nullable`.
2. **SOLID, checked on every change:**
   - **S** — controller = HTTP only; service = one use case; `DomainException`
     subclasses carry business failures, `ApiExceptionHandler` is the ONE place
     mapping them to HTTP.
   - **O** — extend by adding beans (new `PaymentGateway`), not by editing
     `if/else` chains.
   - **L** — implementations honour the interface contract (tests prove it).
   - **I** — small, client-specific interfaces (e.g. `PayoutRequestService` for
     viewers vs `PayoutReviewService` for admins); never a fat interface.
   - **D** — depend on interfaces/repositories, never on another service's
     concrete class; constructor injection, `private final` fields.
3. **Transactions & money safety:** `@Transactional` lives on service impls. The
   reward flow (§4C) stays one atomic SERIALIZABLE transaction using the
   conditional `UPDATE` (`tryDecrementBudget`, `tryMarkPaid`, `tryTransition`);
   never replace those with read-modify-write saves. Never reward outside a
   transaction.
4. **Tests:** JUnit 5 + Mockito + AssertJ for services (pure unit tests, no
   Spring context; every new Strategy/Rule/Mapper/Factory/event gets its own test); `@SpringBootTest` + Testcontainers for DB behaviour
   (Docker must be running). Test names describe behaviour. Integration tests
   must not depend on execution order or on rows other tests insert.
5. **API contract:** routes, status codes and JSON field names are a contract
   with both frontends and the Flutter app — a change needs the three clients
   updated in the same change. Controller path/query params get explicit names.
6. `./gradlew test` must be green before you say a backend task is done.

### 0.3 Frontend rules (Next.js 16 / React 19 / Tailwind 4 — `company_panel`, `admin_panel`)

1. **One UI kit.** All shared look-and-feel lives in `packages/ui` (`@uziy/ui`):
   `Button`, `IconButton`, `SegmentedControl`, `Card*`, `Badge`, `Input`,
   `NumericInput`, `Textarea`, `Select`, `PageHeader`, `StatCard`, `Sidebar`,
   `SidebarUser`, `Topbar`, `ContentShell`, `PageContainer`, `cn`, plus tokens
   in `src/theme.css`. If both panels need the same kind of button/control,
   build it THERE once (with a test) and import it — never hand-write a raw
   `<button>`/styled div in a page or copy a component between panels.
2. **Design tokens only** — colours/spacing via CSS variables
   (`var(--color-…)`); no hard-coded hex in components except the documented
   gradient/contrast constants. Professional, restrained graphite look with the
   gold accent used sparingly; sticky top bar + grouped sidebar; tables get the
   shared styling.
3. **Browser-only state** (localStorage etc.): read it with `useStoredUser()`
   (or another `useSyncExternalStore` hook), **never** `auth.getUser()` during
   render (hydration mismatch) and **never** `setState` synchronously inside
   `useEffect` (ESLint `react-hooks/set-state-in-effect`).
4. **Whole-number inputs** use `NumericInput`; never `type="number"` +
   `Number(value)`.
5. The company panel shows the **company's own name** (sidebar subtitle,
   footer, greeting) — never a hard-coded one; the admin sidebar shows the
   signed-in admin's phone.
6. `pnpm exec tsc --noEmit`, `pnpm exec eslint` and `pnpm exec vitest run`
   must be clean in the app(s) and in `packages/ui` before you say done.
   Install/run from the repo root (`pnpm install`; `pnpm -C <app> dev`).

### 0.4 Mobile rules (Flutter `viewer_app`)

1. **Bottom navigation is fixed and static**: no sliding capsule or
   transition animation; every tab is an icon with its **label underneath**;
   the active tab is gold with the filled icon. The **Нүүр tab uses the custom
   Instagram-Reels-style glyph** (`ReelsIcon`); Хэтэвч/Профайл use Material
   icons. Custom glyphs go through `AppNavItem.glyphBuilder`.
2. **Never wrap the `ShellRoute` child (the nested Navigator) in an
   `AnimatedSwitcher`** — it throws `'_dependents.isEmpty'`. Tab animation, if
   any, belongs in the page transition (`_tab`).
3. Parse API JSON defensively and exactly as the backend sends it (e.g. question
   `type` is `SINGLE_CHOICE`, no `campaign_id` field); every `fromJson` change
   gets a model test.
4. `flutter analyze` clean and `flutter test` green before reporting done.

---

## 1. Project at a glance

**Targeted Rewarded Video Platform** (Зорилтот урамшуулалт видео систем).

Mongolian ad-tech product where:

- **Companies** pay to deliver 30 s – 2 min videos to demographically-targeted
  viewers.
- **Viewers** watch a video fully → answer 2–3 survey questions → receive
  ~500–700 ₮ of that spend into their in-app wallet.
- **Super Admin** oversees everything and takes a 30–40 % commission.

The user (project owner) is building this for the Mongolian market. Copy in the
UI is in Cyrillic Mongolian; currency is ₮ (tögrög).

**Tech stack agreed with the user (do not swap without asking):**

- Flutter (viewer + company apps) — this repo's `viewer_app/` starts that.
- React or Flutter Web for the Super Admin dashboard (not started yet).
- Spring Boot (Java 17) backend.
- PostgreSQL (schema drafted in `docs/SPEC.md` §3).
- Cloudflare R2 for video storage (chosen for zero egress cost).
- FFmpeg or AWS MediaConvert for HLS transcoding.
- DigitalOcean or Hetzner ($6–$12/mo VPS) for hosting.

---

## 2. Repo layout (as of this handoff)

```
rewarded-video-platform/
├── CLAUDE.md                          ← you are here
├── docs/
│   └── SPEC.md                        ← verbatim original product brief
└── viewer_app/                        ← Flutter viewer app (started this session)
    ├── pubspec.yaml
    └── lib/
        ├── main.dart                  entry, ProviderScope + ViewerApp
        ├── app.dart                   MaterialApp.router + AppTheme.dark
        ├── theme/
        │   └── app_theme.dart         dark theme + AppColors palette
        ├── routes/
        │   └── app_router.dart        go_router config + bottom nav shell
        ├── models/
        │   ├── user.dart              AppUser, UserRole, Gender, age getter
        │   ├── campaign.dart          Campaign + mockFeed() for UI dev
        │   └── survey_question.dart   SurveyQuestion + mockFor()
        ├── services/
        │   ├── api_service.dart       Dio singleton, baseUrl TODO
        │   └── auth_service.dart      login/register stubs, secure token storage
        ├── widgets/
        │   └── incentive_banner.dart  the mandatory profiling-incentive banner
        └── screens/
            ├── splash_screen.dart
            ├── auth/
            │   ├── login_screen.dart
            │   └── register_screen.dart
            ├── home/
            │   ├── home_feed_screen.dart
            │   └── video_player_screen.dart
            ├── survey/
            │   └── survey_screen.dart
            └── wallet/
                ├── wallet_screen.dart
                └── payout_request_screen.dart
        └── screens/profile/
            └── profile_screen.dart
```

**Not yet created (intentional — future sessions):**

- `video_worker/` — FFmpeg transcoding worker.

**Decisions locked in during subsequent sessions:**

- **(2026-10-01) Company panel and Super Admin panel are now SEPARATE apps**:
  `company_panel/` (port 3000, routes at `/`, `/campaigns`, `/billing`, …) and
  `admin_panel/` (Super Admin only, port 3001, routes at `/`, `/payouts`,
  `/users`, …). Each has its own `/login` that only admits its own role. UI is shared through
  the pnpm workspace package **`packages/ui` (`@uziy/ui`)**: Button, IconButton,
  SegmentedControl, Card, Badge, Input/NumericInput/Textarea/Select, PageHeader,
  StatCard, Sidebar/SidebarUser/Topbar/ContentShell/PageContainer, `cn`, and the
  design tokens in `src/theme.css`. Need a new look-alike control? Add it THERE
  (with a test), never copy it into a panel. `lib/api|pricing|billing` are still
  per-app copies. Install/run from the repo root: `pnpm install`, then
  `pnpm -C admin_panel dev` / `pnpm -C company_panel dev`. Backend CORS allows both
  origins. Older notes below that say "one codebase / `/company/*` /
  `/admin/*`" are superseded. The leftover files from the split were deleted on 2026-10-06 (admin no longer
  carries company-only code; mock data is gone — the admin sidebar badges use the live
  `/admin/stats` counts).
- The **Company panel is a web app**, not mobile. (Originally merged into
  `admin_panel/` with role-based routing; see the split above.) Rationale: uploading videos, drawing targeting filters, and
  reviewing charts are painful on a phone.
- The app is named **Uziy** (Mongolian "зоос" = coin) — reflected in the
  Next.js metadata and the console login page. The Flutter viewer app still
  says "Rewarded Video" as a placeholder; rename when the marketing pass
  happens.

### `admin_panel/` — Next.js 16 + React 19 + Tailwind 4 + TS

Serves BOTH the Company panel and the Super Admin panel from one codebase.
Route roots: `/login`, `/company/*`, `/admin/*`.

```
admin_panel/
├── package.json                      Next 16, React 19, Tailwind 4, lucide-react
├── tsconfig.json
├── next.config.ts
├── AGENTS.md                         auto-generated warning from Next 16
├── app/
│   ├── layout.tsx                    root <html lang="mn"> + globals
│   ├── globals.css                   dark theme, CSS vars mirroring viewer_app
│   ├── page.tsx                      redirects to /login
│   ├── login/
│   │   └── page.tsx                  role picker (Company vs Admin) + login
│   ├── company/
│   │   ├── layout.tsx                sidebar + shell for company role
│   │   ├── page.tsx                  dashboard: stats + campaign table
│   │   ├── campaigns/
│   │   │   ├── page.tsx              grid of campaign cards
│   │   │   ├── new/page.tsx          5-step wizard (video → targeting →
│   │   │   │                         budget+cost calculator → survey builder
│   │   │   │                         → review). Cost-per-view is derived
│   │   │   │                         from targeting precision, per spec §6.
│   │   │   │                         Video length is NOT typed — it's read
│   │   │   │                         from the picked MP4's metadata
│   │   │   │                         (lib/video.ts); "Дараах" stays disabled
│   │   │   │                         until a readable 5–180 s video is picked.
│   │   │   └── [id]/page.tsx         detail: stats + survey response bars
│   │   ├── analytics/page.tsx        placeholder — "coming soon"
│   │   ├── billing/page.tsx          balance card + invoices
│   │   └── settings/page.tsx         profile + password
│   └── admin/
│       ├── layout.tsx                sidebar w/ pending-count badges
│       ├── page.tsx                  dashboard: GMV/commission/users +
│       │                             live pending payout & pending campaign
│       │                             lists
│       ├── payouts/page.tsx          approval queue. Anti-fraud gate from
│       │                             spec §4A — approve/reject actions;
│       │                             first-payout badge highlights users
│       │                             about to be flipped is_verified=TRUE.
│       ├── users/page.tsx            searchable/filterable list w/
│       │                             verify/ban actions
│       ├── campaigns/page.tsx        moderation queue: approve/reject
│       │                             pending campaigns
│       └── finance/page.tsx          monthly GMV/commission/payout ledger
├── components/
│   ├── sidebar.tsx                   Sidebar + ContentShell (client comp
│   │                                 because of usePathname active state)
│   ├── page-header.tsx               title + description + actions row
│   ├── stat-card.tsx                 label / value / trend / icon
│   └── ui/
│       ├── button.tsx                variants: primary/secondary/ghost/
│       │                             danger/success; sizes sm/md/lg
│       ├── card.tsx                  Card + CardHeader + CardBody
│       ├── input.tsx                 Input, Textarea, Select — dark theme;
│       │                             NumericInput for every whole-number
│       │                             field (money/age/seconds): text state,
│       │                             clearable, strips leading zeros. Never
│       │                             use type="number" + Number(value) —
│       │                             an emptied field snaps to "0".
│       └── badge.tsx                 tones: neutral/success/danger/warning/
│                                     info/primary (using color-mix)
└── lib/
    ├── utils.ts                      cn(), formatTugrik(), formatNumber(),
    │                                 relativeTime(), formatDuration() (m:ss),
    │                                 sanitizeIntInput()/parseIntInput()
    │                                 backing NumericInput
    ├── video.ts                      readVideoDuration(file) — browser-side
    │                                 metadata read (floors seconds so the
    │                                 viewer full-watch gate is reachable);
    │                                 MIN/MAX_VIDEO_SECONDS, status copy
    └── mock-data.ts                  Campaign, User, Payout, SurveyResponse
                                      types + fixtures used by every page
                                      until the backend is wired
```

**How to run the console:**

```
cd admin_panel
pnpm install   # already done during scaffold
pnpm dev       # http://localhost:3000 → redirects to /login
```

Every route (13 total) has been warm-compiled with a curl smoke test — all
return 200. `pnpm exec tsc --noEmit` passes cleanly.

**Design tokens live in `app/globals.css`** as CSS custom properties
(`--color-primary`, `--color-surface`, etc.) that mirror the Flutter
`AppColors` palette. Do NOT bake colors directly into Tailwind classes — use
`bg-[var(--color-primary)]` so viewer_app and admin_panel stay visually
consistent.

**All mock data lives in one place** (`lib/mock-data.ts`) and the "current
user" is hardcoded to company-100 (MobiCom) / an admin. Swap these for real
session data once the backend + auth are wired.

### `backend/` — Spring Boot 4 + Java 17 + PostgreSQL

**Layering rule (SOLID, refactored 2026-10-01):** controllers are thin HTTP
adapters; every use case is a `FooService` interface + `FooServiceImpl`
(`@Service`, owns `@Transactional`); services depend on repositories and
interfaces only and throw `DomainException`s. Put new logic in a service,
not a controller, and write the service's unit test with JUnit 5 + Mockito + AssertJ.
**(2026-10-06) The backend was converted from Kotlin to Java 17** (no Lombok; DTOs are
`record`s, entities are plain classes with getters/setters, nullable lookups return
`Optional`). Sources are `src/main/java` / `src/test/java`. SOLID rules: one use-case
interface per client (e.g. `PayoutRequestService` / `PayoutReviewService`), constructor
injection only, depend on interfaces, extend via new beans (`PaymentGateway`).

The API consumed by both frontends. **Fully working end-to-end** as of
this session — every endpoint below has been smoke-tested with curl.

```
backend/
├── build.gradle.kts                Spring Boot 4.1.1, Java 17, JJWT 0.12
├── docker-compose.yml              uziy-postgres (Postgres 16, port 5432)
├── README.md                       run/env/endpoint reference
├── gradlew, gradle/                bundled wrapper
├── src/main/resources/
│   ├── application.yml             env-driven config (DB, JWT, CORS)
│   └── db/migration/
│       ├── V1__init_schema.sql     spec §3 tables + indexes + constraints
│       └── V2__seed_dev_data.sql   dev users + 3 campaigns + questions
└── src/main/java/mn/uziy/backend/
    ├── UziyBackendApplication.java
    ├── config/
    │   ├── AppProperties.java        @ConfigurationProperties("uziy")
    │   └── WebConfig.java            registers AuthArgumentResolver
    ├── domain/
    │   ├── UserEntity.java           + Role, Gender enums, computed .age
    │   ├── CampaignEntity.java       + SurveyQuestion, ViewHistory,
    │   │                           SurveyResponse (JSONB via @JdbcTypeCode)
    │   ├── PayoutEntity.java         + PayoutStatus
    │   └── *Repository.java          split per aggregate (User, Campaign+Payment,
    │                               Survey*/ViewHistory, Payout); findFeedFor()
    │                               implements §4B; tryDecrementBudget() is the
    │                               conditional UPDATE for §4C.
    ├── common/DomainException.java   NotFound/Forbidden/BadRequest/Conflict/
    │                               Unauthorized/Unavailable — services throw
    │                               these, never ResponseStatusException.
    ├── web/ApiExceptionHandler.java  the ONE place domain exceptions → HTTP status
    │                               (sendError, so the JSON `message` is unchanged)
    ├── security/
    │   ├── JwtService.java           issue/parse; HS512 signed with app secret
    │   ├── JwtAuthFilter.java        Bearer → SecurityContext
    │   ├── SecurityConfig.java       stateless, CORS, role-gated routes
    │   └── CurrentUser.java          @Auth param resolver → JwtPrincipal
    ├── auth/                       AuthController (HTTP) → AuthService
    ├── viewer/                     ViewerController → ViewerService (me/feed/
    │                               questions) + RewardService.submitSurvey
    │                               ← THE atomic tx (§4C), SERIALIZABLE.
    ├── company/                    CompanyController → CampaignService
    │                               (create/list/get/setStatus) +
    │                               CampaignPaymentService (pay/list)
    ├── payment/                    PaymentGateway interface; SimulatedPaymentGateway.
    │                               New provider = new @Component, nothing else
    │                               changes (first isAvailable() gateway is used).
    ├── payout/                     PayoutController → PayoutService
    ├── settings/                   PlatformSettingsController → ...Service
    └── admin/                      AdminController → AdminStatsService,
                                    UserAdminService, CampaignModerationService
```

**Run locally:**

```
cd backend
docker compose up -d postgres
./gradlew bootRun     # migrations + dev seed run automatically
```

**Proven working end-to-end (smoke tests done this session):**

- POST /auth/register/viewer → JWT
- GET /viewer/feed → correctly filtered by age/gender/city/status,
  correctly excludes already-watched campaigns
- POST /viewer/campaigns/1/submit → HTTP 200, balance credited 700 ₮
- Second submit for same campaign → HTTP 409 CONFLICT (double-reward blocked)
- POST /viewer/payouts (500 ₮) → balance reserved (200 ₮ left, PENDING request)
- PATCH /admin/payouts/{id}/decision?decision=APPROVED → user's is_verified
  flipped to TRUE (§4A anti-fraud gate)

**JSONB columns** (`survey_questions.options_json`, `survey_responses.answer_json`)
use `@JdbcTypeCode(SqlTypes.JSON)` — do NOT remove that annotation or inserts
will fail with a `varchar → jsonb` cast error.

**Dev-seed passwords are hard-coded BCrypt hashes** that may not match
"password" — always register a fresh user via `/auth/register/viewer` for
testing, don't rely on the seed users being login-able. (Fix: real BCrypt
hashes in `V2__seed_dev_data.sql` — small future task.)

**There is no admin-create endpoint** — to make an admin, run:

```
docker exec uziy-postgres psql -U uziy -d uziy \
  -c "UPDATE users SET role='ADMIN' WHERE phone_number='XXXXXXXX'"
```

This is intentional: admins should never be self-created. Add a proper
super-admin bootstrap flow before shipping.

---

## 3. What each file does (viewer_app)

### `pubspec.yaml`

Dart SDK ≥ 3.4, Flutter ≥ 3.22. Deps: `go_router`, `flutter_riverpod`, `dio`,
`flutter_secure_storage`, `intl` (`video_player`/`chewie`/`shared_preferences` were
removed on 2026-10-06 as unused — re-add `video_player` + `chewie` when the real player lands).
**Playback is still a placeholder** —
`VideoPlayerScreen` renders a placeholder timer; wire the real player later.

### `lib/main.dart`

`WidgetsFlutterBinding.ensureInitialized()`, transparent status bar, wraps
`ViewerApp` in `ProviderScope`. Riverpod is set up but no providers exist yet.

### `lib/app.dart`

`MaterialApp.router` with `AppTheme.dark()` and `appRouter`.

### `lib/theme/app_theme.dart`

- `AppColors`: `background #0B0B0F`, `surface #16161C`, `surfaceElevated
#1F1F27`, `primary #FFCE00` (Mongolian gold), `accent #3B82F6` (blue),
  `success #22C55E`, `danger #EF4444`, `textPrimary #F5F5F7`, `textSecondary
#9CA3AF`, `divider #2A2A33`.
- `AppTheme.dark()`: Material 3, dark scheme, rounded 12–14 radii,
  primary-yellow-on-black buttons.

### `lib/routes/app_router.dart`

- `Routes` static-string constants for every path.
- `ShellRoute` hosts a `NavigationBar` (Feed / Wallet / Profile) around
  `/home`, `/wallet`, `/profile`.
- `/video/:campaignId` and `/survey/:campaignId` are top-level (no bottom nav —
  full-screen).
- `/wallet/payout` is also outside the shell.

### `lib/models/user.dart`

`AppUser` with a computed `age` getter (correctly handles birthday not yet
reached this year). `fromJson` maps snake_case backend fields.

### `lib/models/campaign.dart`

`Campaign` with `mockFeed()` returning 3 fake Mongolian brand campaigns
(MobiCom, Golomt Bank, UniTel) so the UI works without a backend.

### `lib/models/survey_question.dart`

`SurveyQuestion` with `mockFor(campaignId)` — one single-choice, one
single-choice, one free text.

### `lib/widgets/incentive_banner.dart`

**Contains the verbatim required message from spec §4A.** Do not paraphrase.
Shown on the register screen.

### `lib/screens/splash_screen.dart`

1.2 s delay → `context.go(Routes.login)`. TODO comment marks where to plug in a
real auth-token check via `AuthService.readToken()`.

### `lib/screens/auth/login_screen.dart`

Phone + password form. Phone is 8 digits with `+976` prefix. Fake submit →
`context.go(Routes.home)`.

### `lib/screens/auth/register_screen.dart`

Full profile capture: phone, password, gender chips, birth-date picker (max
= today − 13 years), city dropdown (defaults to `Улаанбаатар`), district text.
`IncentiveBanner` at the top. Fake submit → home.

### `lib/screens/home/home_feed_screen.dart`

Card feed. Header shows a fake wallet chip (`3,400 ₮`). Each card: 16:9
thumbnail placeholder, duration badge top-left, reward badge top-right,
title + company name below. Tap → `/video/:id`.

### `lib/screens/home/video_player_screen.dart`

**Placeholder playback** — a `Timer.periodic` advances `_elapsed` every 250 ms.
The "Continue to survey" button is disabled until `_elapsed >= duration` —
this is the full-watch gate the spec requires. Tap toggles paused state. When
you wire the real `video_player`/`chewie` widget, replace the RadialGradient
placeholder and drive `_elapsed` from the player's position stream.

### `lib/screens/survey/survey_screen.dart`

Wizard-style survey with progress bar. Supports `singleChoice`,
`multipleChoice`, `text`. Final submit shows a bottom sheet:
"Урамшуулал таны хэтэвчинд орлоо +N ₮" then routes home. Real backend call
belongs at the `_submit()` TODO — it triggers the atomic transaction in spec §4C.

### `lib/screens/wallet/wallet_screen.dart`

Gold balance card + fake transaction history (rewards + one payout). Tap
"Мөнгө татах" → `/wallet/payout`.

### `lib/screens/wallet/payout_request_screen.dart`

**This is the anti-fraud gate from spec §4A.** Collects bank + account number

- account holder name + national ID (АА99999999 format, 10 chars). Success
  dialog explains that Admin will match the account name against profile data
  and flip `is_verified = TRUE`. Wire the POST here.

### `lib/screens/profile/profile_screen.dart`

Avatar + phone + verified badge + gender/age/city rows + menu tiles
(history / help / privacy / logout). Logout → `/login`.

### `lib/services/api_service.dart`

Dio singleton, `baseUrl = 'https://api.example.com'` (TODO — replace with the
real VPS URL). `setAuthToken()` toggles the `Authorization` header.

### `lib/services/auth_service.dart`

`FlutterSecureStorage` for the JWT. `login()` and `register()` throw
`UnimplementedError` — the network shapes are documented in commented code so
the next session can uncomment once the backend exists.

---

## 4. Design decisions worth knowing

- **Dark theme by default.** All screens assume dark; there is no light-mode
  toggle. Reward-app aesthetic borrows from TikTok / Snap.
- **Gold `#FFCE00` primary** is a nod to Mongolian gold accents. All CTAs use
  it against black text.
- **Copy is Mongolian Cyrillic throughout.** If you add new strings, match the
  tone (short, informal, second-person plural "Та"). Don't switch to Latin.
- **No i18n system yet** — strings are inline. If localization comes up, hoist
  them to `flutter_localizations` / ARB files then.
- **Mock data lives on the models.** `Campaign.mockFeed()` and
  `SurveyQuestion.mockFor(id)` power the UI so it renders standalone. Delete
  those factories once the backend is wired.
- **Riverpod is installed but unused.** No providers yet. When adding state,
  put them under `lib/providers/`.
- **go_router**, not `Navigator`. Use `context.go` for tab-level nav and
  `context.push` for pushes; the `ShellRoute` handles the bottom nav.

---

## 5. TODO markers in the code (grep for `TODO:`)

| File                         | TODO                                                                    |
| ---------------------------- | ----------------------------------------------------------------------- |
| `splash_screen.dart`         | replace timer with real auth-token check                                |
| `login_screen.dart`          | wire `AuthService.login`                                                |
| `register_screen.dart`       | wire `AuthService.register`                                             |
| `video_player_screen.dart`   | swap placeholder for real HLS player                                    |
| `survey_screen.dart`         | POST to `/surveys/submit` — this triggers the atomic 3-step transaction |
| `wallet_screen.dart`         | bind balance/history to real user state                                 |
| `payout_request_screen.dart` | POST to `/payouts/request`                                              |
| `profile_screen.dart`        | bind to logged-in user; add edit flow                                   |
| `api_service.dart`           | set the real `baseUrl`                                                  |
| `auth_service.dart`          | implement `login` / `register`                                          |

---

## 6. Suggested next steps (in order)

1. **Run the viewer app.** From `viewer_app/`:
   ```
   flutter run
   ```
   Confirm splash → login → register (terms checkbox) → home → video →
   survey → reward sheet works end-to-end. iOS 26 on iPhone 16 Pro is
   already known-working.
2. **Run the console.** From `admin_panel/`:
   ```
   pnpm dev
   ```
   Open http://localhost:3000 → pick a role → hit /company or /admin.
3. **Wire the frontends to the backend.**
   - In `admin_panel/`, replace `lib/mock-data.ts` reads with a
     `lib/api.ts` client that hits `http://localhost:8080`, and store the
     JWT in a cookie or localStorage after `/auth/login`. Every page
     already consumes the same DTO shapes the backend returns.
   - In `viewer_app/`, fill in `api_service.dart` (set `baseUrl`) and
     `auth_service.dart` (uncomment the Dio calls). Then swap the
     placeholder timer in `video_player_screen.dart` for `video_player` +
     `chewie` playing the real `.m3u8` URL.
4. **Video worker** (`video_worker/`). Small container running FFmpeg:
   accepts `POST /transcode` (or an S3/R2 event), outputs 480p/720p/1080p
   HLS `.m3u8` + `.ts` chunks, uploads to Cloudflare R2, then calls back
   `PATCH /company/campaigns/{id}` with the resulting URL. The backend
   currently accepts the `videoUrl` string directly — no upload endpoint.
5. **Real seed passwords + admin bootstrap.** Rewrite
   `V2__seed_dev_data.sql` with actual `BCrypt("password")` hashes so the
   seeded users can be logged into, and add a one-time admin-bootstrap
   Gradle task (`./gradlew makeAdmin --phone=XXX`) that hashes a password
   and inserts a row with `role='ADMIN'`.

---

## 7. Non-obvious constraints & gotchas

- **Never reward-issue outside a DB transaction.** Spec §4C is a hard
  requirement — `view_history` insert, budget decrement, balance increment
  must be one atomic op. Fraud/double-reward risk otherwise.
- **The register screen enforces min age = 13** (`DateTime(now.year - 13)`).
  If regulators require higher (18?), change `_pickBirthDate`.
- **Phone validation is exactly 8 digits** (Mongolian numbering plan). Do not
  accept international-format input in the viewer app.
- **`is_verified` is set by the Admin at first payout**, not at registration.
  This is the anti-fraud mechanism — profile data must match bank/ID at cash-out.
- **Cloudflare R2 was chosen specifically for the egress-fee reason** — do
  not silently swap for S3, GCS, or Azure Blob without discussing cost.

---

## 8. The placeholder key in the original brief

The brief mentioned `CloudFront Dev Public Key ID: K1ABCDEFGHIJ12` at the top.
That value is a placeholder pattern (sequential letters), not a real key. It
is not stored in the codebase. If a real CDN key is provisioned later, put it
in an untracked `.env` file — never commit.

---

## 9. Working style notes for the user

- The user asked for "every generated line of code" to be documented so a
  future session could pick up cold — that's what this file is for. Keep it
  updated whenever you add / rename / delete files.
- The user works out of `/Users/justturuu/Documents/` and this project sits
  in `/Users/justturuu/Documents/rewarded-video-platform/`.
- Auto mode is on; the user is comfortable with you making reasonable
  assumptions and pressing forward on low-risk work. Ask before destructive
  actions or before swapping technology choices from the spec.
