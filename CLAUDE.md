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

### 0.3 Frontend rules (Vite 8 / React 19 / TanStack Router / Tailwind 4 — `console`; Next.js 16 only in `landing`)

0. **One console app (owner, 2026-10-30; replaced `company_panel` + `admin_panel`)**: `console/` is a Vite SPA on
   port 3000. Companies use the root (`/`, `/campaigns`, `/campaigns/new`, `/campaigns/$id`, `/analytics`, `/billing`,
   `/settings`), admins `/admin/*` (`/admin`, `/admin/payouts`, `/admin/campaigns[/$id]`, `/admin/users`,
   `/admin/companies[/$id]`, `/admin/insights`, `/admin/finance`, `/admin/pricing`, `/admin/admins`). Routes are
   code-based in `src/router.tsx` (pages lazy-loaded per area); each area's layout route has a `beforeLoad` guard
   (`src/shared/session.ts` `areaRedirect`: no session → `/login`, other role → its own home). Layout:
   `src/company/{pages,components,lib}`, `src/admin/{pages,components,lib}`, `src/login/`, `src/shared/`
   (`api/http.ts` fetch + token + `useStoredUser`, `api/auth-api.ts`, `api/platform-settings.ts`, `api/types.ts`,
   `navigation.tsx`, `session.ts`, `test/fixtures.ts` builders `aMe`/`aCampaign`). Aliases `@shared/*`,
   `@company/*`, `@admin/*`. Pages never import the router: they use the Adapter in `@shared/navigation`
   (`useRouter().push/replace`, `usePathname`, `useParams`, `Link href`); tests mock that module with
   `importOriginal` so `Link` stays real. Each area's `lib/api.ts` is a Facade re-exporting the shared plumbing.
   `VITE_API_BASE_URL` (build time) replaces `NEXT_PUBLIC_API_BASE_URL`. Data fetching is still per-page
   `useEffect` loading; TanStack Query is NOT adopted yet (a separate refactor — ask before starting it).
0b. **DTO types are generated, never retyped** (2026-10-30): `packages/api-types` (`@uziy/api-types`, `Schema<"CampaignDto">`)
   is generated from `docs/api/openapi.json` by `pnpm -C packages/api-types generate`; its test fails when the
   committed `src/schema.ts` is stale. Request bodies with richer TS than the backend can say (`CreateCampaignBody`
   union, `QuestionType`, `InsightFilter`) stay hand-written next to the calls.

1. **One UI kit.** All shared look-and-feel lives in `packages/ui` (`@uziy/ui`):
   `Button`, `IconButton`, `SegmentedControl`, `Card*`, `Badge`, `Input`,
   `NumericInput`, `Textarea`, `Select` (custom listbox — never a native `<select>`, its popup ignores the theme; API `options` + `onValueChange`), `PageHeader`, `StatCard`, `Sidebar`,
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
   **Both panels are light (owner, 2026-10-21; company followed admin the same day)**: the shared
   `packages/ui/src/theme-light.css` (imported by each app's `globals.css` AFTER `theme.css`) overrides the token
   VALUES in an unlayered `:root` (soft off-white page `#f6f6f3` and sidebar `#fafaf8` with white cards — pure white was too harsh, owner 2026-10-21; deep amber `--color-primary` #975b06 with white text
   on it, darker success/danger/warning/accent). `theme.css` still holds the dark defaults (nothing uses them now). Text on a filled control
   uses `--color-on-primary` / `--color-on-success` / `--color-on-danger` (never a hex); the sidebar uses
   `--color-sidebar`, floating menus `--shadow-popover`. `packages/ui/src/theme-light.test.ts` checks WCAG AA for the
   light palette, the type scale and that the dark defaults did not move; each app's `app/theme.test.ts` checks it
   imports the light theme and the shared font (`console/src/theme.test.ts`). Overlays on fixed dark artwork (campaign thumbnails) use fixed white
   ink (`text-white`) and put badges on `--color-surface`.
   **Console type (owner, 2026-10-21: softer, a bit larger)**: the font is **Rubik**, defined once in
   `packages/ui/src/fonts.css` (`@uziy/ui/fonts.css`: `@fontsource-variable/rubik`, self-hosted, every subset by
   unicode-range — Ө/Ү and ₮ need the -ext ones; it sets `--font-rubik`); the console's `globals.css` imports it.
   Never load a font from Google or define it a second time. Small sizes are tokens in `theme.css` — `text-4xs` 9 / `text-3xs` 10 /
   `text-2xs` 11 / `text-ui` 13px (the dark defaults); `theme-light.css` raises them and Tailwind's
   `--text-xs`/`--text-sm` by 1px. Never write `text-[11px]`-style sizes in the kit; use the tokens. A new size step must also be added to
   `EXTRA_TEXT_SIZES` in `packages/ui/src/cn.ts`, or tailwind-merge takes it for a colour and drops it.
4. **Whole-number inputs** use `NumericInput`; never `type="number"` +
   `Number(value)`.
5. The company area shows the **company's own name** (sidebar subtitle,
   footer, greeting) — never a hard-coded one; the admin sidebar shows the
   signed-in admin's phone.
   **One sign-in page**: companies AND admins sign in on `/login` (`src/login/login-page.tsx`,
   `useConsoleLogin({ roles: ["COMPANY", "ADMIN"] })`); both keep their token here and land on `homeFor(role)`
   (`/` or `/admin`). The 2026-10-22 cross-app session handoff (one-time codes, `handoff/`, `session_handoffs`) was
   removed with the merge (2026-10-30; V21 drops the table). The `@uziy/ui` `Sidebar` knows no router: pass it
   `pathname` and `linkComponent={SidebarLink}`; an area's home item sets `exact: true`.
   **Sign-in page look (2026-10-22)**: `/login` is `@uziy/ui` `ConsoleLoginPage` (Template: brand panel with
   headline, lead and `LoginHighlight`s beside a form card; under `lg` only the card + brand row). The app passes its
   own words, logo and `useConsoleLogin` state — never re-copy the layout into an app.
6. `pnpm exec tsc --noEmit`, `pnpm exec eslint .` and `pnpm exec vitest run`
   must be clean in `console`, `packages/ui` and `packages/api-types` (plus `landing` when touched) before you say
   done. Run pnpm from inside a package (each pins `pnpm@10.17.1`; at the repo root corepack picks pnpm 12, which
   applies other lockfile policies). `pnpm -C console dev` (port 3000), `pnpm -C console build`.
7. **Security headers**: `@uziy/ui/security-headers` is the one source. The console's Vite config sends them from
   the dev/preview server and writes `build/nginx/security-headers.conf` on build (`nginxHeaderLines`); production
   CSP has `script-src 'self'` with no `'unsafe-inline'` (`inlineScripts: false`) — never add an inline script to
   `index.html`. A new external origin goes there.
8. **Young dependencies**: new packages are pinned to releases at least two weeks old; `pnpm-workspace.yaml`
   `overrides` holds transitive pins (seroval, @redocly/openapi-core, uri-js-replace — 2026-10-30).

### 0.4 Mobile rules (Flutter `viewer_app`)

1. **Bottom navigation is fixed and static**: no sliding capsule or
   transition animation; every tab is an icon with its **label underneath**;
   the active tab is in the action colour with the filled icon. **Нүүр and
   Хэтэвч use the authored `NavGlyph`s** (`widgets/nav_glyphs.dart`, owner
   2026-10-21: a house with a play-triangle door, a wallet with a coin on its
   clasp; `ReelsIcon` was removed); Профайл uses a Material icon. Custom glyphs
   go through `AppNavItem.glyphBuilder`.
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
│   ├── SPEC.md                        ← verbatim original product brief
│   └── FEATURE_REVIEW.md              ← what is (not) worth building next, and why (2026-10-12)
│   (viewer_app/PRODUCT.md — product record for the Impeccable design skill: users, purpose, constraints; 2026-10-14.
│    Impeccable is installed in .claude/ (skills, agents, hooks in settings.local.json) and .github/ — LOCAL ONLY:
│    every Impeccable file, .impeccable/ and PRODUCT.md are git-ignored (owner, 2026-10-14); never commit them.)
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

- **(2026-10-30) The two panels are ONE app again: `console/`** (Vite SPA, see "`console/`" below and §0.3). The
  2026-10-01 note that follows is history.
- **(2026-10-01) Company panel and Super Admin panel are now SEPARATE apps**:
  `company_panel/` (port 3000, routes at `/`, `/campaigns`, `/billing`, …) and
  `admin_panel/` (Super Admin only, port 3001, routes at `/`, `/payouts`,
  `/users`, …). **(2026-10-22) There is ONE sign-in page — the company panel's `/login`** (see "One sign-in page" below); the admin panel has no form. UI is shared through
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

### `console/` — Vite 8 + React 19 + TanStack Router + Tailwind 4 + TS (2026-10-30)

The company console and the super-admin console in one SPA (rules in §0.3 items 0, 0b, 5–8). Run:
`pnpm -C console dev` → http://localhost:3000 (`/login`; companies land on `/`, admins on `/admin`). In Docker:
`docker/console.Dockerfile` builds it and serves `dist/` with nginx (`docker/console-nginx.conf`: SPA fallback,
1-year cache for `/assets/`, the generated security headers on every location); compose service `console`,
container `uziy-console`, build arg `API_BASE_URL` → `VITE_API_BASE_URL`.

### OpenAPI contract (2026-10-30)

The backend describes its API with springdoc (`api/OpenApiConfig`, `api/RequiredResponseFields`: response records
list every component as required and `@Nullable` ones as `T | null`, matching Jackson which writes nulls; `*Req`
records and records nested in them keep the bean-validation rule). `/v3/api-docs` is OFF everywhere
(`springdoc.api-docs.enabled: false`; `TokenAndExposureIntegrationTest` checks it stays unreachable);
`api/OpenApiContractTest` switches it on for itself and fails when `docs/api/openapi.json` differs. After any
route/DTO change: `./gradlew updateOpenApi` → `pnpm -C packages/api-types generate` → `tsc` in the console →
`flutter test test/contract` (`viewer_app/test/contract/openapi_contract_test.dart` checks every key a Dart
`fromJson` reads exists, and a key read without a null check is required and never null; models are still
hand-written by choice, owner 2026-10-30). It already caught `Me` missing `district` (the profile's Дүүрэг row was
always empty); `Me` now sends it.

### Commission per campaign, set at approval (owner, 2026-10-30)

The platform's cut is no longer one fixed percentage for every campaign.
- **Defaults per kind**: `platform_settings.commission_percent` is the video campaigns' default and
  `survey_commission_percent` (V22) the survey-only one (`PlatformSettingsEntity.commissionPercentFor(hasVideo)`;
  `PlatformSettingsDto`/`UpdatePlatformSettingsReq` gained `surveyCommissionPercent`, required). A new campaign is
  priced with its kind's default — `CampaignServiceImpl.price` — and the company pays that (flow unchanged: create →
  pay → admin approves).
- **The admin sets the campaign's own commission when approving**: `PATCH /admin/campaigns/{id}/moderate?decision=ACTIVE
  &commissionPercent=40` (optional; with REJECTED it is a 400). `admin/CampaignCommission` re-splits what was paid:
  the cost per viewer C and the reach N stay (so the paid total and the budget accounting do not move), the reward
  becomes R = floor(C × (100 − c) / 100) via `CampaignPricing.forViewers(C × N, N, c, min)`; a percentage that drops R
  under the minimum reward, one outside 1–90 (`pricing/CommissionRange`) or a legacy campaign without a snapshot is
  refused and the campaign stays PENDING. Event `CampaignCommissionSet(campaignId, fromPercent, toPercent,
  rewardPerViewer)`. The approval push is sent after commit, so it already shows the new reward.
- **Console**: admin `/admin/pricing` edits both defaults; approving (queue and campaign page) opens
  `components/approve-campaign-dialog.tsx` (starts at the campaign's percentage, previews the reward and the
  platform's income with `lib/commission.ts` `splitAt`, which mirrors the backend; `@uziy/ui` `ConfirmDialog` gained
  `confirmDisabled`). **The company never sees the commission** — no percentage or commission amount in the wizard,
  invoice or campaign page; the wizard previews with `pricingSettingsFor(settings, hasVideo)` and calls the reward
  "ойролцоогоор" because approval may change it. It is still derivable (paid total − rewards) and the campaign JSON
  still carries `commissionPercent`; only the UI hides it.

### Quiz question — "зөв хариулттай" (2026-10-30)

A 5th question type `QUIZ`: a question about the video with exactly one correct option. Owner: optional for the
company; the viewer retries until they pick the right one, and the reward is paid only then.
- **Backend**: `company/QuizQuestion` (only on a video campaign, ≥ 2 different non-blank options, `correctAnswer` one of
  them) checked in `CampaignServiceImpl.validateShape`; `CampaignFactory` stores `survey_questions.correct_answer`
  (V20, with a CHECK) and forces `required`. The correct answer is NEVER in `QuestionDto`. `POST
  /viewer/campaigns/{id}/questions/{questionId}/check {answer}` → `{correct}` (`viewer/QuizController` →
  `QuizCheckServiceImpl`; 404 unless the campaign is ACTIVE and it is that campaign's QUIZ, 400 for an unlisted
  answer). `AnswerValidator` refuses a wrong pick at submit (`WRONG_QUIZ_ANSWER`). Analytics count it like a choice.
- **Console**: the wizard offers 'Зөв хариулттай (видеоны тухай)' only for a video campaign; the company marks the
  correct option with a radio; `lib/survey.ts` `quizError` mirrors the backend rule. Admins do NOT yet see questions
  when moderating a campaign (an older gap).
- **App**: `QuestionType.quiz`; `screens/survey/quiz_logic.dart` `QuizChecks`; the survey checks a quiz pick on
  'Дараах' / 'Илгээх' (`ViewerService.checkQuizAnswer`), a wrong pick is marked on its `OptionTile(wrong: true)` with
  `kQuizWrongMessage` and cannot be sent again; a failed check shows its message and judges nothing.

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

**Or the whole stack in Docker (2026-10-21)** — from the repo root: `docker compose up -d --build` starts
postgres + pgAdmin (included from `backend/docker-compose.yml`), the backend (`backend/Dockerfile`, :8080, healthcheck
on `/actuator/health`) and the console (`docker/console.Dockerfile`, nginx on :3000 since 2026-10-30;
`VITE_API_BASE_URL` is baked at build time, default `http://localhost:8080`, override with
`API_BASE_URL=… docker compose build`). The backend container reads `backend/.env` if present; `DB_URL` etc. are set by
compose. Both compose files are project **`uziy`**; the DB volumes are pinned to their old names
(`backend_uziy_pgdata`, `backend_uziy_pgadmin`) so existing data was kept. Images are production builds: code changes
need `--build`; for hot reload stop the Docker services and use `bootRun` / `pnpm dev`. `.dockerignore` files keep
`.env` and `node_modules` out of the images. Landing and the Flutter app are not in the stack.

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

**Sample surveys for local testing (2026-10-14)**: `backend/dev/sample_surveys.sql` adds five short survey-only
campaigns (3–4 questions, every viewer, 500 ₮, paid + ACTIVE) to the LOCAL database —
`docker exec -i uziy-postgres psql -U uziy -d uziy < backend/dev/sample_surveys.sql`. Idempotent (skips existing titles).
It is not a Flyway migration on purpose: it must never reach production.

**Admin accounts (2026-10-22)**: a signed-in admin opens another admin's account on the admin panel's `/admins`
page ('Админууд', under Тохиргоо): phone + temporary password, shown once to hand over. Backend `admin/`
`AdminAccountController` → `AdminAccountServiceImpl`: `GET|POST /admin/admins` (`CreateAdminReq {phoneNumber,
password}` → 201 `AdminAccountDto {id, phoneNumber, createdAt}`); a phone that already has ANY account is 409
`Messages.ACCOUNT_PHONE_TAKEN` (an existing viewer/company is never promoted); event `AdminCreated` (ids only); the
list read is written to `data_access_log` (`VIEW_ADMINS`). The new admin still passes the SMS second step at every
login, so the phone must be one they hold. Any admin can add admins (no super-admin tier yet), and there is no
remove/disable yet. Panel: the company and admin forms share `lib/account-form.ts` (`credentialsError`,
`companyFormError`, `phoneDigits`, `generateTempPassword`; was `company-form.ts`) and
`components/accounts/` (`CredentialFields`, `HandOverNotice`, `FormError`).
**The very first admin** still has to be made in the database (admins are never self-created):

```
docker exec uziy-postgres psql -U uziy -d uziy \
  -c "UPDATE users SET role='ADMIN' WHERE phone_number='XXXXXXXX'"
```

Add a proper first-admin bootstrap before shipping.

### Profile menu pages (added 2026-10-07)

The three 'Бусад' rows of the profile tab open real pages (routes `/profile/history|help|privacy`,
Cupertino push), all inside `ProfilePageShell` (`screens/profile/profile_page_shell.dart`):
- **History** (`history_screen.dart`, `history_logic.dart`, model `view_history_item.dart`) reads
  `GET /viewer/history` → `List<ViewHistoryItemDto {campaignId,title,companyName,rewardPaid,watchedAt}>`,
  newest first, capped at 100 (`ViewerService.HISTORY_LIMIT`). Backend: `ViewHistoryMapper`,
  `ViewHistoryRepository.findByUserIdOrderByWatchedAtDesc`.
- **Icons**: the profile area uses the Lucide set (`lucide_icons_flutter`) through one vocabulary,
  `lib/theme/app_icons.dart` (`AppIcons.history`, …) — ask there, never pick a glyph in a screen.
  (`phosphor_flutter` was tried but does not compile on Flutter 3.47: `IconData` is final.)
- **Help** (`help_screen.dart`) — FAQ accordion; copy lives in `help_content.dart`.
- **Privacy** (`privacy_screen.dart`) — copy in `privacy_content.dart`. The text is a first draft
  and needs the owner's / a lawyer's review before release.

### Guest browsing (added 2026-10-07)

The app opens on Home for everyone — no forced login. Splash always goes to `/home`.
- **Backend**: `GET /public/feed` (open in `SecurityConfig`, package `guest/`) returns up to
  `GuestFeedService.SAMPLE_SIZE` (5) newest campaigns that can still pay, **untargeted and with
  `videoUrl` blanked**. `/viewer/**` stays VIEWER-only.
- **Flutter**: `AuthService.isSignedIn` (sync, = Authorization header set). `HomeFeedScreen` reads
  the guest feed when signed out; a card tap or the header 'Нэвтрэх' pill opens `GuestGateSheet`
  (Бүртгүүлэх / Нэвтрэх). `routes/auth_gate.dart` holds the rules: router `redirect` sends a guest
  from `/wallet*` and `/profile*` to `/login?next=<page>`; `next` travels through login/register and
  `finishAuth` opens it afterwards (a tapped campaign is looked up in the viewer's own feed; if it
  is not there the viewer stays on Home with a note). Login has a 'Зочноор үзэх' button back to Home.

### Landing page (added 2026-10-12)

`landing/` — public marketing site for viewers (Next.js 16, port 3002, static, in the pnpm workspace).
Hero + 4 steps + benefits + FAQ (native `<details>`) + a 'Компаниудад' block linking to the company panel.
- **Every visible sentence** lives in `lib/content.ts` (Cyrillic, "Та"; videos 30 s–2 min, 2–3 questions, min age 13,
  phone proved by texting a code to 144773 — keep in step with the app). Components only render it, so the positioning
  test covers the whole page. Sections: hero (+ interactive `PhoneDemo`), how it works (4 steps), benefits +
  a `#privacy` panel (companies never see name/phone, groups under 5 hidden, written answers not tied to a person,
  in-app account deletion), for companies (accounts are created by Uziy: 'Бидэнтэй холбогдох' with an email and/or phone
  button from `NEXT_PUBLIC_CONTACT_EMAIL` / `NEXT_PUBLIC_CONTACT_PHONE`, the login demoted to a text link; with neither set
  only the login shows — never a made-up address), FAQ, download. Critique 2026-10-22 (23/32, snapshot in
  `.impeccable/critique/`): owner asked for better Mongolian wording rather than a bigger redesign or a teen angle.
- Copy + design pass (owner, 2026-10-22): no eyebrow labels above headings, no unicode arrows as icons (lucide only),
  body text ≥ 14–16px (the sample-survey phone is 320px with ≥ 10px type — it is interactive), the font loads the
  `cyrillic-ext` subset (Ө/Ү fell back to another font before; `app/layout.test.ts`).
- **Taste pass (owner asked for the `design-taste-frontend` skill, 2026-10-22; a restyle, layout and palette kept)**:
  headings are one string in one ink (no two-tone `accent` part, `splitAccent` deleted), ≤ 6 words (hero ≤ 5;
  `lib/content.test.ts`); the hero title spans the full width (2 lines at 1440) with copy + phone below; the steps are a
  list in large type (no icons, no index numbers); benefits have no icon boxes; no hairlines, header blur or resting
  shadows outside app fragments: separation is tone (`--tone`) and space; FAQ rows are filled, the +/× is CSS.
  Running text uses `--body` (≈ 9:1), `--muted` is for notes only. The phone and the report card are marked `data-ui`
  (cropped app pieces: they keep their own lines/shadow, CSS for them is scoped `[data-ui] …`).
  **Motion layer**: parts marked `data-reveal` (+ `style={revealOrder(n)}` for the stagger, `lib/reveal.ts`) rise in
  once via `components/motion-layer.tsx` (IntersectionObserver). `<html data-motion="on">` is set by that script only,
  so without JS or with reduced motion nothing is hidden. Keep `revealOrder` and the constants in `lib/reveal.ts`: a
  server component that imports a plain function from a `"use client"` file gets a client reference and the page 500s.
  The phone drifts slowly (`phone-drift`). Skill checks: `lint.mjs` 0 FAIL; `inspect.mjs` (needs Node 22, or Node 20
  with `--experimental-websocket`) still reports 2 FAIL on purpose — no real photos yet (stock pictures of strangers
  would mislead; needs real app screenshots/photos from the owner) and the hero is 3 lines at 390px (five long
  Mongolian words; 34px is the largest size that holds 3 lines).
- Links are deploy-time config (`lib/links.ts`, see `.env.example`): `NEXT_PUBLIC_APP_STORE_URL`,
  `NEXT_PUBLIC_PLAY_STORE_URL`, `NEXT_PUBLIC_COMPANY_PANEL_URL`, `NEXT_PUBLIC_SITE_URL`. Empty store URL ⇒
  the store button is disabled and says 'Удахгүй' (no fake links).
- **Positioning rule (owner, 2026-10-12)**: the page sells brands' introductions + the viewer's opinion (surveys).
  It must NOT mention money at all — no ₮ amounts, reward, wallet, payout (`lib/content.test.ts` enforces it).
- `@uziy/ui` gained `ButtonLink` (an `<a>` with the exact `Button` look; shared `buttonClasses`).
- Run: `pnpm -C landing dev`. Checks: `tsc --noEmit`, `eslint`, `vitest run`, `build` all clean.
- Real store URLs, app screenshots in the phone mock, and a privacy/terms page are still to do.

### Rating question — mood slider (added 2026-10-12)

A 4th question type `RATING`: the viewer drags a thumb across **Муу / Дунд / Сайн** and a face reacts.
- **Contract**: `type: "RATING"`; the answer is one of the three label strings (stored/validated exactly like a
  single choice). The company sends **no options** — `CampaignFactory` always stores `RatingScale.LABELS`
  (`company/RatingScale.java`), so analytics (`AnswerCounter`/`SegmentCounter`) count it with no special case.
  `AnswerValidator` treats `RATING` as a choice. DB: `V8__rating_question_type.sql` widens the `q_type` CHECK.
- **Company panel**: builder offers 'Үнэлгээ (Муу · Дунд · Сайн)' (no options editor, explanatory note);
  `lib/survey.ts` `takesOptions(type)` decides which types need typed answers; `QuestionType` is exported from `lib/api.ts`.
- **Flutter** (`screens/survey/`): `mood_logic.dart` (pure: `moodShapeAt`, `moodTintAt`, `moodPanelAt`, `moodIndexFor`, word
  carousel maths, `MoodColors` — coral → brand gold → mint) + `mood_slider.dart` (`MoodSlider`,
  `MoodFacePainter`, `MoodThumbPainter`, `MoodWordCarousel`). Only the SHAPES change while dragging: eyes and
  mouth never move (circles → flat pills → big circles; frown → flat → smile). The panel is the app's dark surface
  (only a 10 % wash of the mood, `kMoodPanelWash`); the mood colour is used for the face, the word, the travelled
  track and the thumb — never a big bright background. The big word is a carousel that slides sideways with the thumb. Release snaps with a bounce + haptic per stop; tap a
  label/track jumps; semantics slider (increase/decrease); reduce-motion jumps. The thumb rests on Дунд and
  nudges twice until touched — `onChanged` only fires from real input, so an untouched slider = unanswered.
  A plain tap also emits a drag *cancel* — `_dragging` guards it (regression-tested).
- **Flat, not gradient (owner, 2026-10-12)**: `AppButton` primary is a flat `AppColors.primary` fill (no gradient, no glow)
  and `RewardChip` is flat gold — plain fills read as hand-made, gradients as generated. Other `AppGradients.gold`
  uses (coin, wallet card, avatars) are still there; flatten them the same way if the owner asks.
- **Never hand-roll JSON** (bit us twice, 2026-10-12): `QuestionMapper.parseOptions` split options on commas, so
  'Тийм, сүүлийн сард' became two options and every submit answered 'Хариулт буруу байна'; the app's answer encoder
  only escaped quotes, so a text answer with Enter/Tab was invalid JSON. Both now use a real JSON codec
  (Jackson / `jsonEncode`, `ViewerService.encodeAnswer`). `CampaignFactory.optionsJson` uses Jackson too (2026-10-22):
  no JSON is hand-rolled anywhere any more — keep it that way.
- **Fixed on the way**: the app's `QuestionType` parser did not know the backend's real `MULTI_CHOICE`, so
  multiple-choice questions silently opened as single choice. `QuestionType.fromWire` now maps the wire names.

### Company analytics (added 2026-10-07)

`company_panel` `/analytics` (page + `lib/analytics.ts` + `components/daily-bars.tsx`, `distribution-bars.tsx`;
no chart library, plain SVG/CSS, one hue, hover + keyboard tooltip, table view).
- **Backend** (`analytics/`): `GET /company/analytics?days=7..90&campaignId=` (COMPANY only) →
  `{days, totals, campaigns[] (responses, reach %, spent, rewards, cost/response), daily[] (zero-filled,
  Ulaanbaatar calendar days), audience {gender, ageBands, cities} | null, questions[] (only with campaignId)}`.
  `audience` is `null` below `MIN_AUDIENCE_SAMPLE` (5) responses so nobody can be singled out; free-text
  answers are never returned. Native SQL lives in `ViewHistoryRepository` / `SurveyResponseRepository`;
  `AnswerCounter` (Jackson) counts choice answers; `AgeBands` groups ages. A `date` column comes back as
  `LocalDate` on Hibernate 7 (the integration test caught it).
- **Insights** (`lib/analytics.ts` `buildInsights`, shown in `InsightsCard`): week-over-week change, budgets that
  run out within 7 days at last week's pace, cheapest vs dearest answers, running campaigns with no responses.
  **No hour-of-day data (owner, 2026-10-22: not relevant to companies)** — `hourly` was removed from the API and the
  panel. With a campaign selected, `segments[]` answers "who chose what" (men/women/age bands); a segment under
  `MIN_SEGMENT_SAMPLE` (5) answerers is never returned. Charts draw at their measured pixel width
  (`useElementWidth`) so text never scales up on wide screens.
- **Per-survey results (2026-10-22)**: `components/survey-results.tsx` (logic `lib/survey-results.ts`, data
  `lib/use-campaign-results.ts`) is the ONE results view, used on `/campaigns/[id]` ('Судалгааны хариултууд') and on
  `/analytics`: per question the answer bars (choices by count, ratings in scale order) and 'Хэн юу гэж хариулсан' —
  answer × gender × age band, percent within each group (`SegmentTable`), with the small-group privacy note; text
  questions say written answers are not shown. Question and segment results always cover the campaign's whole life
  (the `days` window applies to the daily series only).
- **No browser dialogs**: `window.confirm/alert/prompt` are never used in the panels — use `@uziy/ui` `ConfirmDialog`
  (native modal `<dialog>`, focus kept inside, Esc/backdrop close, danger/primary tone, optional required text field,
  busy state). Finishing a survey and rejecting a payout use it.

### Security audit & production readiness (added 2026-10-07)

Full write-up and checklist: **`docs/PRODUCTION_CHECKLIST.md`**. Rules that now hold for every change:
- **Money moves only through atomic SQL** (`UserRepository.tryDeductBalance` / `addBalance`,
  `PayoutRepository.tryClaim`, `CampaignRepository.tryDecrementBudget`); never `setBalance` + `save`.
  `UserEntity` is `@DynamicUpdate` so a stale entity cannot overwrite a balance.
- A reward needs: targeting match (`CampaignTargeting`), valid answers (`AnswerValidator`), then the budget
  claim; it is wrapped by `RetryingRewardService`.
- Every endpoint is covered by `security/AccessControlMatrixIntegrationTest` (add new routes there!); object
  access by `ObjectAccessIntegrationTest`; abuse/injection/races by `ApiAbuseIntegrationTest`; tokens, headers,
  CORS, error hygiene by `TokenAndExposureIntegrationTest`. They share one Postgres container
  (`AbstractApiIntegrationTest`) and use fresh phone numbers (`freshPhone()`) because the login lock is per phone.
- `SPRING_PROFILES_ACTIVE=prod` + `ProductionReadinessCheck`: the app will not boot with dev secrets, seeded
  accounts, simulated payments, logging OTP or localhost CORS. `application-prod.yml` has no secret defaults.
- Known open risk: rewards cannot yet be tied to real watching (see the checklist).

### Second security audit (2026-10-22) — rules that now hold

Details and the open decisions: `docs/PRODUCTION_CHECKLIST.md` ("Second audit").
- **Never load-modify-save a `UserEntity`** for a single field: a phone check or any slow step in between lets a
  payout run, and the save writes the old balance back. Use a one-column conditional UPDATE (`trySetPassword`,
  `markVerified`, `trySetNameOnce`, the balance methods).
- **Password change = sign-out everywhere**: `users.credentials_changed_at` (V16); `JwtAuthFilter.stillValid` refuses
  tokens issued before it (whole seconds). Set it whenever a password changes.
- New passwords carry `@BcryptSafe` (≤ 72 UTF-8 bytes); `ViewerAgeRule` (13+) runs at viewer registration.
- Statistics count only a yes to the CURRENT consent wording (`InsightsRepository.CONSENTING`).
- Never log personal data: no DB error detail (constraint name only), no push text, no phone/account/token.
- **Local Docker**: Postgres and pgAdmin listen on 127.0.0.1 only; 8080 stays on the LAN for the phone, so
  `backend/.env` holds a random `JWT_SECRET` (template in `.env.example`; never the committed dev default).
- **Panels**: every Next app sends `@uziy/ui/security-headers` (`securityHeaderRoutes`, CSP with the API origin,
  frame-ancestors 'none', HSTS in prod). A new external origin (CDN, analytics, images) must be added there.
- **App**: secure storage only through `appSecureStorage` (`services/secure_store.dart`: iOS this-device-only, Android
  encrypted prefs — a test fails on any other `FlutterSecureStorage(`); print only through `debugLog(() => …)`
  (`services/debug_log.dart`), never a bare `debugPrint`; the debug network log masks password/newPassword/
  accountNumber/token (`services/api_log.dart`); release builds refuse a non-https `API_BASE_URL`
  (`ApiService.ensureConfigured` in `main.dart`); the verify page opens only `sms:` links (`smsLaunchUri`); logout
  clears `MoneyMemory`. Android `allowBackup="false"`. Switching the keychain options signed existing iOS users out once.

### Admin & company accounts (2026-10-22)

- **Console phone check is OFF by default (owner, 2026-10-26)**: `uziy.console-login.phone-check`
  (`CONSOLE_LOGIN_PHONE_CHECK`, `AppProperties.ConsoleLogin`, default `false`) — admins and companies sign in with the
  password alone (200 + token). `ConsoleLoginServiceImpl.appliesTo` is false for every role then, so no check is opened
  and `/auth/login/verify` refuses. Turn it on (true) to get the flow below back; its tests run with it on through
  `AbstractPhoneCheckedConsoleLoginIntegrationTest`. The panels need no change: a 200 just signs in.
- **Console login = password + phone check on an unknown browser (2026-10-22; owner: companies AND admins, 30 days;
  only when the switch above is on)**:
  `POST /auth/login {phoneNumber, password, deviceToken?}` — a viewer gets 200 `{token, user}` (deviceToken ignored); an
  ADMIN/COMPANY with a valid device token gets the same 200; otherwise **202** `{twoStep: {verificationId, phoneNumber
  (masked), role, shortcode, smsText, smsUri, displayInstruction, expiresAt}}` with no token (wrong password = 401, no SMS).
  The person texts the code from the account's phone, then `POST /auth/login/verify {phoneNumber, verificationId}` →
  `{token, user, deviceToken, deviceTrustedUntil}`. Purposes `ADMIN_LOGIN` / `COMPANY_LOGIN` (V17, V18) — role-bound, opened
  only by the login, claimable 5 min. Packages `consolelogin/` (event `ConsoleSignedIn(userId, role, newDevice)`) and
  `trusteddevice/`: table `trusted_devices` keeps ONLY the SHA-256 of the device token (+ browser family label), 30 days
  (named constant), ≤ 10 per user (least recently used dropped), valid only if created after `credentials_changed_at`;
  password reset, account deletion and `POST /admin/users/{id}/trusted-devices/forget` (admin, company detail page,
  'Төхөөрөмжүүдийг мартах') delete them. Panels: the whole flow lives once in `@uziy/ui` (`console-login.ts`,
  `console-login-step.tsx`); the device token is kept in localStorage `uziy.device` and survives logout. The per-phone
  SMS limits (60 s cool-down, 5/hour) apply to these checks too. Locally the Docker backend uses real verify.mn (text from
  the account's real phone); with `simulated` run the curl the backend logs.
- **Companies are created by the admin only**: `POST|GET /admin/companies` (`admin/CompanyAccount*`, event
  `CompanyCreated`); `POST /auth/register/company` is gone (404). Admin panel 'Компаниуд' page (temporary password shown once).
- Admin payout history masks decided account numbers (`common/Masking`, `•••• 4567`); pending ones stay full.
  Admin reads of users/payouts/companies write `data_access_log` (`VIEW_USERS`, `VIEW_USER`, `VIEW_PAYOUTS`,
  `VIEW_PAYOUT_HISTORY`, `VIEW_COMPANIES`).
- Admin users page: phone search + place list (`@uziy/ui/regions`) + company menu (`Select` gained `searchable`);
  logic in `admin_panel/lib/user-filters.ts`.
- Every data table in both panels sits in `@uziy/ui` `TableScroll` (scrolls sideways inside its card; without it a
  wide table widened the whole page on a 1024px laptop). New tables must use it.

### Account deletion & store readiness (2026-10-22)

- `DELETE /viewer/me {password}` → 204 (package `account/`): personal data cleared in place (phone → `DEL-<id>` so the
  number can register again; names, birth date, city, consent cleared; password unusable; tokens die via
  `credentials_changed_at`), device tokens + phone checks + free-text answers deleted, choice answers kept anonymous,
  decided payouts kept for accounting with holder name removed and the account masked; 409 while a payout is pending;
  any balance is forfeited (the app warns). Event `ViewerDeleted`. App: Profile → 'Бүртгэл устгах'
  (`delete_account_sheet.dart`): a short sheet (owner, 2026-10-22) — two lines `kDeleteSheetPoints` + the balance warning; the full rules (`kDeleteAccountFacts`) live on the privacy page. Owner/accountant should confirm the retention choice.
- Store config: ids above, version from pubspec, Android release signing from git-ignored `android/key.properties`
  (template `key.properties.example`; no key ⇒ debug-signed APK with a warning, App Bundle refused), adaptive +
  monochrome icons, iPhone-only, `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption=false`, ATS local networking
  added only to Debug builds by `ios/scripts/allow_local_networking_in_debug.sh`. `test/platform/store_config_test.dart`
  guards it. Owner's manual steps (Apple/Play accounts, keys, Firebase files, privacy + deletion URLs, reviewer demo
  account): **`viewer_app/RELEASE.md`**.

### Error-prone spots hardened (2026-10-22)

- Company analytics: `analytics/SmallGroupRule` hides slices under 5 AND the next smallest when the hidden remainder
  would be 1–4 (no differencing); option counts only from 5 answers; panel shares are of all responses.
- `company/TargetAgeRule`: age range ≥ 5 years (mirrored in `company_panel/lib/targeting.ts`).
- Phone checks: per-phone Postgres advisory lock (`PhoneVerificationRepository.lockPhone`) makes the cool-down atomic.
- `LoginAttemptLimiter`: bounded (50,000 phones, oldest evicted), no full scans.
- App: free-text answers capped at the backend's JSON length as typed (`kMaxAnswerJsonLength`); a pasted '5,000.00'
  payout is 5,000 not 500,000; `WalletCardSkeleton` and `PayoutHistoryRow` no longer overflow at 320pt / large text;
  `test/screens/survey/survey_screen_test.dart` drives the whole survey at 320pt @1.3–1.5x.

### Error messages users read (added 2026-10-13)

Every error a client can show is Cyrillic Mongolian and says what to do; nothing technical or echoed.
- **Backend**: `web/SafeErrorAttributes` is the one renderer. A message `ApiExceptionHandler` sent (domain
  exceptions, field validation — marked with the `OWN_MESSAGE` request attribute) is kept, at any status; anything
  Spring answers by itself ("Forbidden", UUID conversion, unknown route, 413, 5xx) gets a Mongolian sentence per
  status (`messageFor`). The `errors` list (it echoes rejected values, e.g. passwords), traces and exception names
  are always removed. Field validation answers with the first failing field's own message: put a
  `message = FieldMessages.X` on every constraint of a user-facing request (`common/FieldMessages`); constraints
  without one fall back to `resources/ValidationMessages.properties` (Mongolian). Wording shared by several services
  is in `common/Messages`. Never throw a `DomainException` with English or `null` text.
- **Flutter**: `services/api_error.dart` `apiErrorMessage(...)` is the one mapper (backend `message` → network /
  timeout → per-call `byStatus` → 401/403, 429, 5xx → fallback); `kUnexpectedError` for non-API failures. Never show
  `$e`, `e.error` or a URL to the user.
- **Panels**: `lib/api.ts` `apiFetch` throws `ApiError` with the backend message, `GENERIC_ERROR_MESSAGE` when there is
  none, and `NETWORK_ERROR_MESSAGE` (status 0) when the server cannot be reached.

### Phone verification for registration — verify.mn (added 2026-10-13)

Registration proves the phone the other way round: the **viewer texts** a 6-digit code FROM their phone to
verify.mn's short code **144773** (mobile-originated SMS; the user's operator charges them 150 ₮ per SMS).
- **Backend** (`phoneverify/`): `POST /auth/phone-verifications {phoneNumber}` → 201
  `{verificationId, phoneNumber, shortcode, smsText, smsUri, displayInstruction, status, expiresAt}` (409 taken
  phone, 429 = 60 s cool-down / 5 per hour, 503 provider down); `GET /auth/phone-verifications/{id}` →
  `{verificationId, status: PENDING|VERIFIED|EXPIRED, expiresAt}`. `POST /auth/register/viewer` now takes
  `verificationId` (UUID) **instead of `otpCode`**; `VerifiedPhoneClaim.claim` spends it once (conditional
  UPDATE `tryClaim`: same phone, VERIFIED, unused, verified < 30 min ago) inside `registerViewer`'s transaction.
  Table `phone_verifications` (V9). `PhoneVerificationGateway` Strategy: `VerifyMnGateway`
  (`PHONE_VERIFICATION_PROVIDER=verifymn`, `VERIFY_MN_API_KEY` required, key only sent on POST and never
  logged; we **poll**, no callback endpoint) | `SimulatedPhoneVerificationGateway` (default `simulated`:
  nothing texted; a check stays PENDING until a developer "delivers" the SMS with
  `POST /auth/phone-verifications/simulated-sms/{sessionId}` — the backend log prints the exact curl; that route
  exists only in simulated mode; `ProductionReadinessCheck` refuses simulated). Until 2026-10-13 the simulator
  verified at the first poll, so the app registered before any SMS — regression test in `ApiAbuseIntegrationTest`.
  Local secrets: `backend/.env` (git-ignored, see `.env.example`) is loaded by `./gradlew bootRun` only, never by tests. A pending row is refreshed
  from the provider on every GET and once more on claim; a provider outage leaves it PENDING.
- **Flutter**: register form → `AuthService.startPhoneVerification` → `PhoneVerifyScreen` (`/register/verify`,
  `extra: PendingRegistration(draft, verification)`; logic in `phone_verify_logic.dart`). Shows the code + 144773
  (`SmsCodeCard`), the provider's `displayInstruction` **verbatim** (names the SIM to send from), 'SMS илгээх'
  opens `smsUri` via `url_launcher` (injectable `launchSms`), polls every 3 s (and on app resume), and on
  VERIFIED stops polling, hides the button and registers itself. EXPIRED (or 10 s past `expiresAt`, or a 400 at
  registration) → 'Шинэ код авах' opens a new check and says the old code is void.
- **Callback** (verify.mn → us) is not implemented; add a `GET` route that only triggers a status check, and
  whitelist 3.34.8.248 / 13.124.219.192, if push-speed confirmation is ever wanted.

### Password reset — verify.mn (2026-10-14; replaced the 2026-10-07 OTP codes)

A forgotten password is proved exactly like registration: the viewer **texts a code FROM the phone** to 144773.
The old OTP path (`otp/` package, `otp_codes` table, `LoggingOtpSender`, `POST /auth/otp/request`, `OTP_SENDER`) is
gone — it only ever wrote codes to the server log.
- **Backend**: `phone_verifications.purpose` (`REGISTER` | `PASSWORD_RESET`, V12; V12 also drops `otp_codes`).
  `POST /auth/phone-verifications {phoneNumber, purpose?}` — `purpose` defaults to `REGISTER`; REGISTER → 409 for a
  taken phone, PASSWORD_RESET → **404 'Энэ дугаараар бүртгэл олдсонгүй…' for a phone with no viewer account, before
  any SMS** (owner's choice: registration already reveals taken numbers, and a stranger must not pay 150 ₮ for
  nothing). `VerifiedPhoneClaim.claim(id, phone, purpose)` — a check is spent only for its own purpose (`tryClaim`
  matches `purpose`). `passwordreset/`: `POST /auth/password/reset {phoneNumber, verificationId, newPassword}` → 204;
  `PasswordResetServiceImpl` (viewers only, one transaction) also clears the login lock. The code generator moved to
  `phoneverify/VerificationCodeGenerator`. Existing JWTs stay valid after a reset (no token revocation yet).
  Tests: `PasswordResetFlowIntegrationTest` (reuses the scripted provider of `PhoneVerificationFlowIntegrationTest`).
- **Flutter**: login 'Нууц үг мартсан?' → `ForgotPasswordScreen` (`/forgot`, opens a PASSWORD_RESET check) →
  `PhoneVerifyScreen.passwordReset` (`/forgot/verify`, extra `PendingPasswordReset`, `models/password_reset.dart`) →
  on VERIFIED `ResetPasswordScreen` (`/forgot/reset`: new password only; a 400 offers 'Дахин эхлэх'). The verify page's
  behaviour per purpose is the sealed `PhoneCheckGoal` (`RegisterGoal` | `PasswordResetGoal`). `OtpInput`,
  `otp_logic.dart` and the resend timer were removed; `otp_widgets.dart` keeps `OtpHeader` / `OtpErrorText`.

### Places: aimags and capital districts (added 2026-10-14)

Registration offers **Улаанбаатар + all 21 aimags** by their official names; **Улаанбаатар requires a district** from
its 9 (дүүрэг), an aimag takes an optional typed sum. A viewer's `city` must equal a campaign's `targetCity`
character for character, so the SAME list lives in three places — change all three together:
`backend common/MongolianRegions.java`, `viewer_app lib/models/regions.dart`, `packages/ui/src/regions.ts` (`@uziy/ui/regions`,
used by both panels; `company_panel/lib/regions.ts` only re-exports it; a test compares it with the Java file).
- **Backend**: `auth/ViewerLocationRule` (called in `AuthServiceImpl.registerViewer` before the phone check is spent)
  → 400 'Аймаг эсвэл хотоо жагсаалтаас сонгоно уу' / 'Улаанбаатарт амьдардаг бол дүүргээ сонгоно уу' / 'Дүүргээ
  жагсаалтаас сонгоно уу'. `CampaignServiceImpl` refuses a `targetCity` that is not `ALL` or a listed city.
  `V13__mongolian_regions.sql` renamed the old town values (Дархан → Дархан-Уул, Эрдэнэт → Орхон, Чойбалсан →
  Дорнод, Мөрөн → Хөвсгөл, Өлгий → Баян-Өлгий) in `users.city` and `campaigns.target_city`; 'Бусад' was left as is.
- **Flutter**: `screens/auth/location_fields.dart` (`LocationFields`, `RegionDropdown`), used by `register_screen.dart`;
  `districtFor(city, input)` decides what is sent. Changing the city clears the district.
- **Company panel**: the targeting picker uses `TARGET_CITY_OPTIONS` ('Бүх аймаг, хот', Улаанбаатар, aimags).

### Survey cover images — company side (added 2026-10-14)

Covers are stored by the `media/` package (`CampaignImageService`, table `campaign_images`, V14; served at
`GET /public/campaigns/{id}/image`; JPG/PNG ≤ 5 MB, re-encoded). The admin edits any cover
(`/admin/campaigns/{id}/image`). **Companies** edit their OWN survey's cover with `POST|DELETE
/company/campaigns/{id}/image` (`company/CompanyCampaignImageController` → `CompanyCampaignImageServiceImpl`):
owner only (`OwnedCampaigns`, 403 otherwise) and **only before approval** — `AWAITING_PAYMENT` / `PENDING`; after that
409 'Батлагдсан судалгааны зургийг өөрчлөх боломжгүй' (the cover is part of what the admin approves).
- **UI kit**: the editor is `@uziy/ui` `ImageUploadCard` (+ `coverImageError`): preview, save, remove, `lockedNote` for
  read-only. Admin's `CampaignImageEditor` and the company's `components/campaign-cover-card.tsx` (`CampaignCoverCard`)
  are thin wrappers around it — don't fork it.
- **Company panel**: the cover card sits on the wizard's payment step (the survey exists by then) and on
  `/campaigns/[id]`; `lib/campaign-status.ts` `canEditCover(status)` mirrors the backend rule. `lib/api.ts` `apiFetch`
  sends a `FormData` body as multipart; `companyApi.uploadImage/removeImage`, `mediaUrl(path)`.

### Anonymous statistics + consent (added 2026-10-14) — see `docs/DATA_PRODUCTS.md`

For selling aggregate insights later. **Owner decisions**: separate opt-in consent (default no, revocable), smallest
group **50**. Added on my own judgement (flag to the owner): **minors (< 18) are never counted or asked**.
- **Consent** (`privacy/`, V15 `users.stats_consent|_at|_version`): `GET|PUT /viewer/consents/statistics {granted}` →
  `{status: UNASKED|GRANTED|DECLINED, decidedAt, version}`; a consent to an older `CURRENT_VERSION` wording reads as
  UNASKED. App: `widgets/stats_consent.dart` — only `StatsConsentTile` (the give/withdraw switch, on Profile →
  Нууцлалын бодлого under the statistics section; owner took it off the Profile list on 2026-10-21; it must stay
  somewhere, the consent is revocable). **Nobody is asked any more (owner, 2026-10-21)**: the one-time Home card
  `StatsConsentPrompt` (and `canAskStatsConsent`) was removed, so a viewer is counted only after turning the switch on
  themselves (regression test in `home_feed_completion_test.dart`). Privacy page has a section. Copy needs a lawyer's review.
- **Statistics** (`insights/`, ADMIN only, `/admin/insights/overview|questions|questions/{id}?gender&ageBand&city|
  questions/{id}/segments|questions/{id}/export.csv|access-log`). ALL rules live in `StatisticsPrivacyPolicy` +
  `InsightsRepository.CONSENTING` — never query people without that filter, never return a count/percent for a group
  that fails `reportable(group, all)`, never include TEXT answers or PII. Every call writes `data_access_log`.
  `AgeBands` and `AnswerCounter.strings` (analytics) are public for reuse.
- **Admin panel** `/insights` ("Статистик" in the sidebar): overview, question explorer, access log, rules card
  (`components/insights/*`); `insightsApi` in `lib/api.ts` (`responseType: "text"` for the CSV).

### Auth screens

- **Flat auth forms (owner's redesign, finished 2026-10-14)**: login and register sit on the plain background (no
  `AmbientBackground`, no card), inside `LoginFieldsTheme` (one field look, corners `LoginFieldsTheme.radius`). A label
  above each field, no placeholders, no leading icons (`PasswordField(showLeadingIcon: false)`, `RegionDropdown` has no
  icon, `BirthDateTile` none). Titles are `AuthPageTitle`; gender is `GenderSelector` (two-part control, no check mark;
  a compact 44pt since 2026-10-22 — the label carries the height, never force the outer box or the halves come up short). Login: brand row with 'Зочноор үзэх' (one line), form, then 'Шинэ хэрэглэгч үү?' + a
  secondary 'Бүртгүүлэх' button. Register shows the spec §4A `IncentiveBanner` (now flat: faint green wash, coin)
  under the title. `GenderOptionCard`, `ChoiceCardGroup`, `PhoneNumberSection`, `AuthFooterLink`, `HowItWorksStrip`
  and `authHeroMetrics` were removed with the redesign.
  Polish pass (2026-10-14): 'Бүртгүүлэх' is never disabled — tapped before agreeing, it scrolls to the terms tile, which
  turns red (`TermsAgreementTile.error`) with `kTermsRequired` under it; the tile's box is a flat brand fill. On login
  the 'uziy' name fades first on a narrow screen with large text so 'Зочноор үзэх' is never cut off.
  Critique → layout → bolder (2026-10-14, snapshot in `.impeccable/critique/`, score 23/40 before): register opens
  with the spec banner right under the title (body size, no coin; the '500–700 ₮ per survey' `RewardPromise` was
  removed at the owner's request, 2026-10-21); the pinned button is `kContinueLabel` 'Үргэлжлүүлэх', alone (the `kNextStepNote` SMS/price
  caption above it was removed by the owner on 2026-10-22; the verify page still states the price, `kSmsCostNote`). No city is preselected (`kCityRequired`;
  district/sum appear after a pick). Every labelled field is a `LabeledField` (label hidden from VoiceOver and put on
  the field's own node — MergeSemantics around a TextField asserts). One phone error: `AuthValidators.phoneInvalid`.
  Login = the owner's reference image (2026-10-14, palette unchanged; supersedes the earlier inline-prompt version):
  `LoginBackdrop` (`login_backdrop.dart`, vector sage swells top-right + paper folds at the bottom, 3–6 % brand green,
  no taps/semantics); brand row = `UziyLogo` 44 + 'uziy' 26 + `_GuestPill` ('Зочноор үзэх ›', see-through pill);
  title 'Нэвтрэх' 40 + `kLoginSubtitle`; fields are raised (`LoginFieldsTheme(raised: true)` → `SoftShadowInputBorder`,
  shadow painted only outside the field); `PhoneField(adorned: true)` = '+976' capsule + hairline + phone glyph,
  password has the lock glyph; placeholders `kPhoneHint` / `kPasswordHint`; 'Нууц үг мартсан?' right-aligned under the
  password; 'Нэвтрэх' is `AppButton(raised: true, trailingIcon: AppIcons.next)`; then '— Шинэ хэрэглэгч үү? —' and a
  secondary 'Бүртгүүлэх'. `AppButton` gained `trailingIcon` (label stays centred) and `raised` (soft offset shadow).
  Registration keeps flat fields; field corners are 16 everywhere (`LoginFieldsTheme.radius`).
  The rest of the auth flow follows it (2026-10-14): every auth page title is `AuthPageTitle` (40, optional subtitle);
  forgot / reset / phone-verify drop `AmbientBackground` for the plain paper, use `AuthStepAppBar` + `AuthBackButton`
  (44pt see-through round chevron) and raised fields; forgot uses the adorned phone field; main actions are raised
  (forward steps with the arrow); `OtpHeader`'s glyph sits on a flat sage tile. Visual rules live in
  `viewer_app/DESIGN.md` ("The Meadow Ledger", rewritten 2026-10-14) — read it before any UI work.
- **Coin (owner, 2026-10-14)**: `CoinIcon` is no longer the lit gold '₮' coin — it is the Uziy mark (`logo_mark.png`)
  on a flat disc of `context.colors.primary`, mark in `onPrimary`, inner ring from 20px. One widget, so every screen
  (feed, video, survey, wallet, profile, register, reward chip) changed together.
- **Phone entry (2026-10-14, replaced the 2026-10-12 slotted `BigPhoneField`)**: login, register and
  forgot-password all use `PhoneField` (`auth_widgets.dart`; register shows it under a plain `FieldLabel`). It is an ordinary `TextFormField` built exactly like `PasswordField` (same
  `body` font, the theme's input decoration, a quiet `+976` in the leading slot where the password field has its
  lock), so the two fields have the same height, font and border — a widget test checks it. Selection, paste and
  autofill work; `PhoneDigitsFormatter` keeps the 8 national digits and drops a pasted `+976`/`976`. The controller
  holds bare digits (screens still read it with `phoneDigits(...)`). In tests type into `find.byType(TextField)`.
- **Survey progress (2026-10-12)**: `SurveyProgress` (`survey_widgets.dart`) sits under the survey header:
  one thick `SegmentedProgress` segment per question plus a caption from `questionsLeftLabel` ('Дахиад 2
  асуулт үлдлээ' / 'Сүүлийн асуулт' / 'Ганцхан асуулт'). Done questions are full, the current one is
  part-filled (`startedFill`) until `hasAnswer(...)` is true, then it fills. `SegmentedProgress` got the
  `currentFill` (0..1) parameter for this; its default of 1 keeps the old look elsewhere.
- `InlineFieldError` skips `AnimatedSize` under reduce-motion (a zero-duration `AnimatedSize` throws in
  layout); the register form uses it for the gender / birth-date errors instead of a private copy.

### Push notifications (added 2026-10-06)

When an admin approves a campaign for the first time (PENDING → ACTIVE; resuming PAUSED →
ACTIVE does NOT notify) every matching viewer's phone (Android + iOS) gets an FCM push:
title "Шинэ видео" / "Шинэ судалгаа", body "{company} · Үзээд {reward} ₮ аваарай", data
`{type: CAMPAIGN, campaignId, hasVideo}`. Matching = the feed rules (gender, age, city, not
already completed).
- **Backend** (`notification/`): `POST /viewer/devices {token, platform: ANDROID|IOS}` (204),
  `DELETE /viewer/devices?token=` (204); table `device_tokens` (V6). `PushSender` Strategy
  (`FcmPushSender` | `LoggingPushSender`), `CampaignPushNotifier` (Observer, @Async, AFTER_COMMIT,
  never fails the approval), `PushMessageFactory`. Off by default: `PUSH_ENABLED=true` +
  `FCM_CREDENTIALS_PATH=<service-account.json>` turn real sending on.
- **Flutter** (`lib/services/push/`): `PushClient` interface over firebase_messaging,
  `PushService` facade (permission asked on reaching Home, token register/refresh, unregister on
  logout), `PushNavigator` opens the video/survey screen. Firebase init failure ⇒ push silently
  off, app unaffected (no `google-services.json` / `GoogleService-Info.plist` are committed).
- **Payout decisions are pushed too (2026-10-14)**: `PayoutPushNotifier` (Observer on `PayoutDecided`, @Async,
  AFTER_COMMIT, never fails the decision) sends to every device of that viewer (`DeviceTokenRepository.findTokensByUserId`).
  `PushMessageFactory.payoutDecided`: 'Мөнгө татах хүсэлт батлагдлаа' / '… татгалзагдлаа', body with amount + bank or
  the refund + reason, data `{type: PAYOUT, payoutId, status}`. Flutter: `PushMessageParser` returns a sealed
  `PushLink` (`CampaignPush` | `PayoutPush`); `PushNavigator` opens the wallet for a payout (`walletRoute`,
  `PushNavigationTarget.go`). The Android channel id stays `campaigns`, its name is now 'Uziy мэдэгдэл'.
- Owner setup steps: `docs/PUSH_SETUP.md`. App ids (2026-10-22): **`mn.uziy.viewer`** (iOS bundle id + Android
  applicationId); debug builds are `mn.uziy.viewer.dev` (iOS) / applicationIdSuffix `.dev` (Android).
- **iOS Debug signing (2026-10-13)**: the Debug configuration signs with `ios/Runner/RunnerDebug.entitlements`
  (no `aps-environment`) and bundle id `mn.uziy.viewer.dev`, so `flutter run` works on a real iPhone with a free
  Apple ID ("Personal team" cannot sign Push). Release signs with `Runner.entitlements` (`aps-environment`
  production), Profile with `RunnerProfile.entitlements` (development) — both need the paid team. On a real phone pass
  `--dart-define=API_BASE_URL=http://<Mac LAN IP>:8080` (localhost is the phone itself); `viewer_app/tool/run_device.sh` does that
  (finds the Mac's Wi-Fi IP, checks the backend answers, then `flutter run`). Debug apps open only from `flutter run`/Xcode.

---

## 3. What each file does (viewer_app)

### `pubspec.yaml`

Dart SDK ≥ 3.4, Flutter ≥ 3.22. Deps: `go_router`, `flutter_riverpod`, `dio`,
`flutter_secure_storage`, `intl`, `video_player` (re-added 2026-10-22 for real playback; `chewie` is NOT used —
the screen draws its own controls).

### `lib/main.dart`

`WidgetsFlutterBinding.ensureInitialized()`, transparent status bar, wraps
`ViewerApp` in `ProviderScope`. Riverpod is set up but no providers exist yet.

### `lib/app.dart`

`MaterialApp.router` with `AppTheme.dark()` and `appRouter`.

### `lib/theme/app_theme.dart`

- **Uziy Meadow** palette (2026-10-13; replaced "Gold Noir"): `AppColors` = the LIGHT palette (paper
  `#F5F7F3`, white surfaces, forest-green primary `#145C45`, white text on primary). `theme_palette.dart`
  `AppPalette(isDark)` gives the matching dark colours; `AppTheme.light()` / `AppTheme.dark()` are one
  `_build(isDark)`. Light, dark or follow-the-device is chosen in Profile → 'Харагдах горим'
  (`widgets/appearance_settings.dart`) and kept by `theme/theme_controller.dart` (secure storage key
  `appearance_mode`, survives logout; `main.dart` restores it, `app.dart` drives `themeMode`).

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

**Real playback (2026-10-22)** — the screen drives a `VideoPlayback` (`video_playback.dart`, Adapter + Strategy;
`playbackFor(campaign)` picks it, injectable as `VideoPlayerScreen.playbackFactory` so tests use a fake):
`NetworkVideoPlayback` wraps `VideoPlayerController.networkUrl` (MP4 or HLS); a campaign with no usable URL (old
dev seeds) gets `TimedPlayback`, the former 250 ms clock. The campaign art is the poster under the video; the stage
takes the video's own aspect ratio; a spinner shows while loading/buffering; a load failure shows `kVideoLoadError`
+ `kVideoRetry` (a new player). Leaving the app pauses it (only a tap resumes). The "Continue to survey" gate opens
when the player reports completed or its position reaches `durationSeconds` (floored, so reachable) and stays open
(`_watched` latch). **Rewind only (owner, 2026-10-22)**: the viewer may go back but never skip ahead — the
`WatchTimeline` takes taps/drags (`onSeek`, shows the watched band `furthestProgress`) and the stage has a
`RewindButton` (`kRewindStep` 5 s since 2026-10-30, was 10; the seconds are drawn inside the arrow); every seek goes through `allowedSeek(target, _furthest)`
(clamped to the furthest point actually played). **Full screen (owner, 2026-10-30)**: the stage's `FullscreenButton`
turns the phone sideways (`kFullscreenOrientations`) and shows only the video edge to edge with `_ImmersiveControls`
over it (exit + title; rewind, timeline and, once watched, 'Судалгаа руу'); a phone simply held sideways gets the
same view (`useImmersiveVideo`: landscape and shortest side < 600, tablets keep the side panel). Leaving full screen
locks the phone upright for this screen; closing the screen frees rotation (`setPreferredOrientations([])`) and
restores the system bars. All controls share `StageGlassButton`. A paused viewer stays paused after a seek; a rewind from the end
plays again and the gate stays open. The stage's own node describes the picture/medallion (`ExcludeSemantics`), but
the rewind and retry buttons keep their own screen-reader nodes. The player lives in the
State, never in `_Stage`, so rotation does not dispose it. Tests: `test/screens/home/video_player_screen_test.dart`,
`video_playback_test.dart`.

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

- account holder name. **The national ID is no longer collected (owner, 2026-10-14)**: the form, the API
  (`CreatePayoutReq` / `PayoutDto` have no `nationalId`; a stray field from an old app is ignored), the admin
  payouts table and `payout_requests.national_id` (dropped in `V10`, stored values deleted) are all gone. Do not
  re-add it without asking the owner. **Amount (2026-10-14)**: a framed input the viewer types into, grouped as they
  type (`PayoutAmountFormatter`, `12500` -> `12,500`; read it back with `payoutAmountOf`, never `double.parse`),
  with the quick-pick chips under it filling the same field; focusing the field selects the amount. The 'Эхний таталт' notice (payout form, route `extra: true`) and the wallet's
  note show only while `isBeforeFirstPayout` — unverified and no waiting/paid request (a rejected one keeps it). Names (2026-10-14): registration asks овог (`lastName`) and нэр (`firstName`)
  separately — `RegisterViewerReq` (letters, spaces, hyphens, apostrophes; max 60; same rule as the app's
  `AuthValidators.lastName/firstName`), `users.last_name/first_name` (V11, null for older accounts and companies),
  returned in `Me`. The wallet card prints `walletCardName`: НЭР ОВОГ in capitals, **only the registered name**
  (owner, 2026-10-21) — an older account without one shows no name; a payout's `accountName` is never used
  (`cardHolderName` was removed). **Older accounts add their name once (2026-10-21)**: the card shows `AddNameChip`
  ('Нэрээ нэмэх') when there is no name → `AddNameSheet` (`screens/wallet/add_name_sheet.dart`, the shared
  `PersonNameFields` from `auth_widgets.dart`, same rules as registration) → `ViewerService.setName` →
  `PUT /viewer/me/name {lastName, firstName}` → `Me`. Backend `viewer/ViewerNameController` →
  `ViewerNameServiceImpl` → `UserRepository.trySetNameOnce` (one conditional UPDATE: only a VIEWER whose BOTH names
  are null), 409 `Messages.NAME_ALREADY_SET` otherwise, event `ViewerNameSet` (audit). Set-once on purpose: the
  name takes part in the payout check, so it is never edited from the app.
- **Reduce-motion and `AnimatedSize`**: an `AnimatedSize` whose duration follows `AppMotion.duration` (zero under
  reduce-motion) throws; use `ReducibleAnimatedSize` (`widgets/`) instead. The admin approves after checking the account is in the viewer's own name and
  flips `is_verified = TRUE`.

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

- **Light + dark themes (2026-10-13).** In widgets read colours and text styles from the context —
  `context.colors.x`, `context.textStyles.x`, `context.gradients.x` — never `AppColors.x` /
  `AppTextStyles.x` directly (those are the light values; `AppTextStyles.tabular` and fixed artwork such as
  the coin, confetti, mood hues and overlays on video/campaign art are the exceptions). Helpers that colour
  something take a REQUIRED `AppPalette` (`walletErrorSnackBar`, `StatusBanner.colorFor`,
  …) so a light default cannot sneak into dark mode. White/black overlays are only for
  surfaces that are dark in both modes (video, campaign art, the green wallet card). Dark-palette text keeps
  WCAG AA — `test/theme/dark_theme_test.dart` checks it. **Dark is neutral graphite (owner, 2026-10-21)**: the
  old green-tinted "forest night" was tiring; dark backgrounds/surfaces/greys/lines carry no tint (the test fails if
  a neutral's chroma > 12/255 or green leads) and the action colour is a soft sage `#8DC4A3` (saturation ≤ 0.36).
  The mood slider's dark colours read `AppPalette(true)` instead of copying hex values.
- **Bank logos on the payout form (2026-10-14)**: `wallet_logic.dart` `kBankLogoAssets` maps each bank name (the
  string the backend stores) to `assets/banks/<name>.png`; `BankLogo` (`wallet_widgets.dart`) shows it (see below) and falls back to the coloured monogram when the file is missing. **(2026-10-14)** The logo is now a 32pt rounded
  square (radius 25 %), drawn edge to edge with no padding; the monogram uses the same shape. Every file must be a
  **256 px opaque square** — the bank's full-bleed app icon, or its bare mark trimmed and centred on white with ~16 %
  margin — `wallet_logic_test` checks the PNG header. Raw downloads (odd sizes, transparent margins) made the logos look
  different sizes; normalise new ones the same way.
- **Home header brand row (2026-10-14)**: `UziyWordmark` (`widgets/brand_logo.dart`) — the bare mark
  `assets/logo_mark.png` (transparent, made from `logo.png`) tinted with `context.colors.textPrimary` + the name
  'uziy', so it is dark on light and light on dark (no white tile). On the right `ThemeModeButton`
  (`widgets/appearance_settings.dart`): a **tap flips light ↔ dark at once** (`ThemeController.oppositeOf` the look on
  screen, so "follow the device" flips too; sun/moon icon spins), a **long press opens the sheet**; a failed save shows a
  snack bar. The sheet (also Profile → 'Харагдах горим') picks a mode with `ThemeModeChoices`: three `ThemeModeCard`s
  with a `ThemePreview` miniature of the home screen in that palette (device = diagonal light/dark split); side by
  side, stacked when they would not fit (small phone + large text). The
  'Үз. Хариул. Урамшуулал ав.' tagline chip was removed at the owner's request, and so was the time-of-day greeting
  ('Өглөөний / Өдрийн / Оройн мэнд', 2026-10-21; `DayPart`/`greetingFor` deleted): the balance pill now sits in the top
  row between the wordmark and `ThemeModeButton`. The title is 'Шинэ судалгаанууд' with no
  explainer under it; Нүүр, Хэтэвч and Профайл titles all use `textStyles.pageTitle` (26 / w700, smaller than `display`). `UziyLogo` (white tile) stays on
  splash/login.
- **Wallet card looks like a bank card (2026-10-14)**: `WalletBalanceCard` (`wallet_widgets.dart`) is ID-1 proportioned
  (`aspectRatio` 85.6/53.98, a minimum — large text may grow it) on fixed forest artwork (`AppGradients.walletCard`,
  same in both themes, white ink): `UziyWordmark(color: white)` + 'ХЭТЭВЧ' + contactless glyph, gold EMV `CardChip`,
  balance, the phone as `maskedCardNumber` ('•••• 9911', `wallet_logic.dart`) and `WalletVerifiedBadge` (fixed
  white/forest). Guilloche waves are painted (`_CardEngravingPainter`); a one-time light sweep (`_CardSheen`, skipped
  under reduce-motion). The payout meter now sits on an `AppCard` UNDER the card, in theme colours.
- **Wallet refreshes itself (2026-10-14)**: an admin's payout decision used to show only after pull-to-refresh.
  `services/auto_refresher.dart` `AutoRefresher` (Observer on the app lifecycle) reloads on resume and, while
  `polling` is on, every 10 s (stops in the background; never two loads at once). `WalletScreen` loads `/viewer/me` +
  `GET /viewer/payouts` (`ViewerService.myPayouts`, model `models/payout_request.dart`), polls only while
  `hasPendingPayout`, reloads after the payout form closes, and shows a snack bar for `newlyDecided` requests.
  **(later 2026-10-14)** The status banner is gone: the wallet page itself lists **'Хэтэвчний түүх'**
  (`WalletHistorySection`): totals (`walletIncome` / `walletSpending` — rejected requests were refunded, so they do
  not count) and every reward (`HistoryRow`, from `GET /viewer/history`) and payout request (`PayoutHistoryRow`: status,
  reject reason, struck-through amount when refunded), merged newest first by `buildWalletHistory` (sealed
  `WalletEntry` = `RewardEntry` | `PayoutEntry`). **Direction first (2026-10-21)**: `moneyFlowOf(entry)` →
  `MoneyFlow.incoming|outgoing|returned`, and `MoneyFlowLook` (`wallet_widgets.dart`) is the one place that maps it to
  a glyph + colour (green ↙ in, red ↗ out, grey ↶ refunded); every history row and the totals use it. The totals are
  two separate cards (`WalletTotalsCard` → two `WalletTotalTile`s, each led by a `MoneyFlowBadge`). `tool/render_design_test.dart`
  renders a `wallet-history` preview with sample rows. The rows sit in a box of `kWalletHistoryBoxHeight` (360) that scrolls
  on its own: `GroupedCard(maxHeight: …)` (shared kit, own `ScrollController` + visible scrollbar; short content keeps
  its natural height; `ClampingScrollPhysics` on purpose — iOS bouncing made the scrollbar shrink and regrow, 2026-10-21; the box drops the
  page's `MediaQuery` padding around its `Scrollbar`, or the nav-bar/home-indicator inset shortened the track by ~100pt and
  the bar never reached the end of the list). The old 'Урамшууллын түүх' link card was removed; Profile's
  'Судалгааны түүх' page stays. Regression test:
  `test/screens/wallet/wallet_screen_test.dart`. Reuse `AutoRefresher` for any other screen that waits on an admin.
- **Finished campaigns leave Home by themselves (2026-10-14)**: Home stays alive under the video/survey routes, so a
  finished card used to linger until pull-to-refresh. `services/campaign_events.dart` `CampaignEvents` (Observer,
  broadcast stream): `ViewerService.submitSurvey` publishes `CampaignCompleted` on success AND on 409 (already
  rewarded). `HomeFeedScreen` drops the card at once (`feed_logic.dart` `withoutCampaign`), remembers the id so an
  in-flight reply cannot bring it back, and reloads quietly for the balance; it also reloads on app resume
  (`AutoRefresher`). Regression test: `test/screens/home/home_feed_completion_test.dart`.
- **Polish pass (owner, 2026-10-21; Impeccable `polish`)**:
  - Home cards have **no 'Үзэх / Бөглөх' button** (the card is the button); the `RewardChip` sits on the publisher line.
  - `RewardChip` is no longer gold: `context.colors.actionWash` fill, `actionLine` hairline, primary ink (AA in both
    themes), no glow. `AppPalette.actionWash/actionLine` are shared with the new `AppButtonVariant.tonal`, which the
    wallet's 'Мөнгө татах' uses (a forest button under the forest card melted into it).
  - `FeedFilterBar` = three natural-width `FeedFilterChip`s (icon + name, flat forest when chosen, sideways scroll if
    tight), no counts. `EarningsHeroCard.lookIn`: flat forest in light, graphite surface + sage money in dark.
  - Wallet: tapping 'Нийт орлого' / 'Нийт зарлага' narrows the history (`WalletHistoryFilter`,
    `filterWalletHistory`, `toggleWalletFilter`; refunded payouts show only under all); `WalletFilterLine` undoes it.
  - **Payout minimum is 5,000 ₮ (owner, 2026-10-21; was 1,000)**: backend `MinimumPayoutRule.MINIMUM_PAYOUT`, app
    `kPayoutMinimum` + `kPayoutMinimumLabel` (all payout copy and the help answer read it); quick picks
    5,000 / 10,000 / 20,000 / 50,000, the form opens on 5,000.
  - Profile's history page is **'Судалгааны түүх'** (`kHistoryTitle`, count 'Бөглөсөн судалгаа'), not 'Үзсэн видеонуудын түүх'.
  - Help FAQ no longer has 'Яагаад надад видео цөөн харагдаж байна?'.
  - Password reset asks the new password **twice** (`ResetPasswordScreen`: 'Нууц үг' + 'Нууц үгээ давтах',
    `AuthValidators.passwordRepeat`); each `PasswordField` has its own show/hide eye.
  - **Birth date = three wheels (owner, 2026-10-22)**: the month calendar (`showDatePicker`) was hard to use, so
    registration opens `showBirthDatePicker` (`screens/auth/birth_date_picker.dart`): a bottom sheet with Он · Сар ·
    Өдөр `CupertinoPicker`s, a centred summary — quiet title, the date as it is said ('2007 оны 2-р сарын 22',
    `birthDateLong`; the dotted form read as a code) and a '19 настай' pill — and 'Сонгох'. `birthDateFrom` cuts the day to the
    month (31 → 28/29) and keeps the bounds of `birthDatePickerBounds`. The highlight band is see-through (it is painted
    over the chosen row) and the wheel text is merged onto the app's text style.
  - A free-text answer's placeholder is `kTextAnswerHint` 'Та хариултаа энд бичнэ үү...' (`survey_widgets.dart`).
  - Reward sheet button is 'Дууссан' with a check (was 'Дараагийн видео үзэх'); its amount is a plain colour.
  - Help is a chat (`HelpChat`, `ChatBubble`): Uziy greets, each FAQ question is the viewer's bubble (right, action
    fill), its answer Uziy's bubble (left, coin avatar).
  - **RATING has five stops**: Маш муу · Муу · Дунд · Сайн · Маш сайн (backend `RatingScale.LABELS`, company
    `RATING_LABELS`, app `kMoodLabels`). Questions are stored with their labels, so older 3-stop questions keep
    working; every mood helper takes `steps` (3 or 5, from the labels). Faces: `kVeryBadFace` (worried brows,
    `browTilt`), `kBadFace`, `kMidFace`, `kGoodFace`, `kVeryGoodFace` (open laugh, `mouthOpen`); 3-stop questions
    draw exactly the old faces (`kLegacyGoodFace`).
- **Video screen copy (2026-10-14)**: the reward line says both steps — 'Видеог бүтэн үзэж, судалгаанд хариулбал
  +700 ₮ хэтэвчинд тань орно' → after the video 'Судалгаанд хариулмагц +700 ₮ хэтэвчинд тань орно'
  (`RewardHintRow`); the locked button reads 'Видео дуусахад судалгаа нээгдэнэ · 12 сек'.
- **Money animation (2026-10-14)**: `AnimatedMoney` no longer counts every number from 0 on each mount. With a
  `memoryKey` (`MoneyMemory.balance` on the Home pill, wallet card and profile) it starts from the amount last shown
  for that key — unchanged ⇒ appears at once (tab switches no longer replay), changed ⇒ an odometer
  (`OdometerText`) rolls only the digits that differ, rightmost first, up for more money / down for less. Without a
  key it still starts at 0 when `animateOnMount` (the survey reward sheet). At rest it is one plain `Text`.
- **Sheets open over the tab bar (2026-10-22)**: a sheet opened from a tab (wallet, home, profile) must go through
  `showAppSheet` + `AppSheetFrame` (`widgets/app_sheet.dart`): root navigator (otherwise the floating tab bar painted
  over 'Нэрээ нэмэх' and covered its button) and one keyboard/home-indicator padding. `test/shell/shell_sheets_test.dart`.
- **Keyboard closes on a tap outside a field (2026-10-14)**: `widgets/dismiss_keyboard_on_tap.dart` wraps the
  whole app once (`app.dart` builder). Do not add per-screen `GestureDetector(onTap: unfocus)` copies; scroll views
  may keep `keyboardDismissBehavior: onDrag` as well.
- **Copy is Mongolian Cyrillic throughout.** If you add new strings, match the
  tone (short, informal, second-person plural "Та"). Don't switch to Latin.
- **No "админ" in viewer-facing copy (owner, 2026-10-14).** Say what happens ('Таны дансны мэдээллийг шалгасны
  дараа …'), not who does it; in policy text use 'эрх бүхий ажилтан'. `test/copy/viewer_copy_test.dart` scans
  `lib/` string literals and fails on the word (comments are fine).
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
2. **Run the console.** `pnpm -C console dev` → http://localhost:3000/login (companies land on `/`, admins on
   `/admin`). Both areas are already wired to the backend.
3. **Wire the frontends to the backend.**
   - In `viewer_app/`, fill in `api_service.dart` (set `baseUrl`) and
     `auth_service.dart` (uncomment the Dio calls). (Real video playback is
     done, 2026-10-22.)
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
