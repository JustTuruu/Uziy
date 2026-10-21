# Local demo feed

`demo_feed.sql` adds 24 clearly marked `[ТЕСТ]` campaigns: 12 everyday-topic surveys and 12 video-feedback surveys, each with five questions covering SINGLE_CHOICE, MULTI_CHOICE, RATING and TEXT.

Apply to the local development database only:

```sh
docker exec -i uziy-postgres psql -v ON_ERROR_STOP=1 -U uziy -d uziy < backend/dev/demo_feed.sql
```

Requires the seeded company `88112233` and platform settings. Uses current commission/minimum reward, SIMULATED payment records and 1,000 responses per campaign. No real payment is made. Normal completion still credits the local viewer wallet. Campaigns target all genders, cities and ages 0–120. Existing completion rules still hide a campaign after answering it; the guest preview still shows only five items.

Stable payment references prevent duplicate insertion. Existing campaigns, answers and balances are not reset. This is deliberately outside Flyway and never runs automatically in production.

Video campaigns share the public Big Buck Bunny trailer (https://media.w3.org/2010/05/bunny/trailer.mp4), verified at 33.003 seconds, and ask about different aspects of it. They are sample content, not genuine company advertisements. The Flutter video screen currently uses a timer placeholder, so adding the URL does not enable real video playback.

Run the integration check from any directory:

```sh
python3 backend/dev/tests/test_demo_feed.py
```

The check creates a uniquely named temporary database in the local PostgreSQL container, copies only the current schema, creates test company/settings rows, applies the seed twice, validates campaign/question counts, question types/options, targeting, pricing and media metadata, then drops the temporary database.
