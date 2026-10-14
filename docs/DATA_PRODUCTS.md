# Data products — anonymous statistics (started 2026-10-14)

Goal: later sell aggregate insights (reports, dashboards, trends) built from viewers' survey answers, the way
Toluna / Kantar do — without ever exposing a person.

## What exists now (phase 1)

| Area | What | Where |
|---|---|---|
| Consent | Separate, opt-in, revocable "Нэргүй статистикт оролцох" (default: no). Asked once on Home, switch in Profile. Versioned (`CURRENT_VERSION`); a new wording asks again. Only adults (18+) are asked or counted. | backend `privacy/`, V15; app `widgets/stats_consent.dart` |
| Protection | One policy class: consenting adults only; groups < 50 hidden; a group whose remainder is < 50 hidden (stops subtraction); counts rounded down to 10; whole percents; free text never; no name/phone/birth date/district leaves the DB (only gender, age band, aimag); every look/export logged. | `insights/StatisticsPrivacyPolicy`, `InsightsRepository.CONSENTING` |
| Super admin | "Статистик" page: panel size by gender/age/aimag, cross-survey question explorer with filters, segment table, CSV export (Excel-ready, formula-safe), access log, the rules card. | admin_panel `/insights`; backend `/admin/insights/**` |
| Audit | `data_access_log` (who, action, detail, when) — append-only. Consent changes go through the audit log (`StatisticsConsentChanged`). | V15 |

## Before selling anything — legal checklist (owner / lawyer)

- [ ] Lawyer reviews the consent text (`kStatsConsentBody`) and the privacy-policy section against the
      Personal Data Protection Law (2021) — purpose, recipients ("байгууллагуудад"), retention, withdrawal.
- [ ] Decide retention: how long answers are kept for statistics; delete-on-account-deletion flow.
- [ ] Data-processing agreement template for buyers (no re-identification, no resale, no joining with other data).
- [ ] Register / notify the data protection authority if required.
- [ ] Decide whether minors stay fully excluded (current rule) — keep it unless the lawyer says otherwise.

## Next phases (not built yet)

1. **Richer profile** — education, occupation, income band, household; optional, with "a fuller profile gets more
   surveys" as the incentive. Each field must also be under the same consent and never sold below k=50.
2. **Profile questions after surveys** — 1–2 short questions ("Машинтай юу?") appended after a survey, stored as
   profile attributes (tags), not as survey answers.
3. **Trend tracker** — the same question asked every quarter (scheduled platform surveys) and charted over time.
4. **Benchmarks** — a company's satisfaction vs. the category average (only categories with ≥ 3 companies so no single
   competitor can be read off).
5. **Buyer access** — paid reports (PDF) and a buyer dashboard / API with the same policy; buyers get their own role,
   never the admin pages; every buyer query logged and rate-limited.
6. **Stronger anonymity** — add small random noise (differential privacy) to published percents once buyers can run
   many queries; limits per buyer per day.
