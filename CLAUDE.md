# CLAUDE.md — Local Pulse

Local Pulse is a 2026 Congressional App Challenge entry by two high school students. The full spec is **BUILD.md**; the concept screenshots are in **docs/concepts/**. Read both before any work.

## The contest rule you must protect

The rules allow AI help only if it is **fully disclosed** and **not the whole technical build**. Judges can ask for the source code. So:

1. **HUMAN-FIRST modules.** This table is the single source of truth (BUILD.md §27 follows it). The students write these themselves. For these files you may explain concepts, answer questions, point to docs, review their code, write or run tests, and suggest fixes in words or small snippets they type in. Do **not** write the implementation for them, even if asked casually. If a student explicitly says "write it for me" for one of these, remind them once of this rule, then do what they decide, and log it.

   | Module | Owner |
   |---|---|
   | `lib/levels.ts` (switch points, hysteresis, place resolution; BUILD.md §16) | Partner |
   | `components/map/spin.ts` (BUILD.md §18) | Partner |
   | `supabase/migrations/0002_upsert_notice.sql` (`upsert_notice` RPC; BUILD.md §9.1) | Partner |
   | `supabase/functions/nws/` and `supabase/functions/az511/` | Partner |
   | `scripts/load-gazetteer.ts` | Yat |
   | `supabase/functions/maricopa-rss/` and `supabase/functions/phx-legistar/` | Yat |
   | `supabase/functions/_shared/logic/geotag.ts`, `politics.ts`, `politics-names.ts` | Yat |
   | `supabase/functions/summarize/` and `supabase/functions/_shared/logic/factcheck.ts` | Yat |
   | `app/sources/page.tsx` copy and the AI disclosure text | Yat |

2. **Everything else** (config, UI components, styling, the other connectors, other `_shared/logic` modules, tests, scripts, docs) you may write, but keep changes small and reviewable, one feature per branch.
3. **Log every session.** At the end of each working session, append a row to `docs/AI_USE_LOG.md`: date, who you worked with, tool ("Claude Code"), what was asked, what was kept, what they changed by hand. Keep it honest and specific.
4. **Commits are the students'.** Suggest commit messages; let them commit. Never rewrite git history.

## Stack

Next.js 16 (App Router) + React 19 + TypeScript + Tailwind v4 · MapLibre GL JS **5.24.0** (not v6) · OpenFreeMap Positron + NASA GIBS Blue Marble · Supabase Postgres/PostGIS + Edge Functions (Deno) + Cron · Vitest + Playwright · Vercel.

Next 16 has breaking changes from older Next.js. Before writing Next code, read the guide in `node_modules/next/dist/docs/` for the API you're using (see AGENTS.md, imported below).

## Commands

```bash
npm run dev                      # Next.js dev server
npm run lint && npm run typecheck && npm test   # before every PR (typecheck = tsc --noEmit, test = vitest run)
npm run e2e                      # Playwright at 393x852 (?safe=59,34), 393x659, 412x804
supabase start                   # local Supabase (Docker)
supabase db reset                # re-run migrations locally (0001 + 0002 only; supabase/sql/schedule.sql is NOT a migration)
supabase functions serve <name> --env-file supabase/functions/.env
supabase db push                 # apply migrations to the hosted project (never paste migrations into the SQL editor)
```

## Working rules

- Build milestone by milestone (BUILD.md §27). Propose a plan, wait for a yes, then build. Don't start the next milestone unasked.
- When BUILD.md and a live API disagree, trust the API and update BUILD.md in the same PR.
- Phone first: check every UI change at 393×852 with `?safe=59,34`, then 412×804 and a laptop.
- Match `docs/concepts/` for layout and style. Ignore the "SAMPLE" tags and "Design mock" label; they're prototype-only.
- `reference/prototype.html` is AI-written reference. Read it for behavior; don't copy it wholesale.
- Colors, radii, shadows and motion come from the tokens in BUILD.md §20 (`app/globals.css`; `lib/tokens.ts` mirrors them for MapLibre). No raw hex in components.
- All visible text goes in `lib/strings.ts`.
- Times: always `timeZone: 'America/Phoenix'`.
- News: store and show headline, outlet, time and link only. Never store or show article text, descriptions or images. Never run AI on news.
- AI never picks severity or decides what is shown. Severity rules are BUILD.md §11.1.
- No government seals or agency logos. Agency names in text only.
- Secrets never in code, commits, logs or client bundles. Only `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` and `NEXT_PUBLIC_SITE_URL` reach the browser.
- Don't log users' coordinates, addresses or searches. Local feed and geocode requests are POST; address autocomplete runs in the browser.
- Every connector: idempotent, catches its own errors, records its run in `sources` under its source id (BUILD.md §9 table), sends a `User-Agent`.
- Respect rate limits: AZ511 10 calls/60 s; GDELT 1 call/5 s (server only, on schedule).
- Pure logic goes in `supabase/functions/_shared/logic/` with no Deno APIs, so Vitest can test it. `supabase/functions` is excluded from the Next `tsconfig` and ESLint.
- Tests first for pure logic. Case tables live in `tests/cases/*.json`; fixtures in `tests/fixtures/` (real samples from Sept 26, 2026; news fixtures are trimmed to headline, link, date and categories: keep them that way).
- Don't add features that aren't in BUILD.md without asking. The stretch list (BUILD.md §1) waits until all 13 must-haves work on a real phone.

@AGENTS.md
