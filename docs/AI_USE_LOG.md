# AI-use log

The 2026 Congressional App Challenge allows AI help only when it's fully disclosed and isn't the whole technical build. Add a row for every AI-assisted session. Copy this table into the submission's AI disclosure.

| Date | Who | Tool | What we asked for | What we kept | What we changed by hand |
|---|---|---|---|---|---|
| 2026-09-24 to 09-26 | Yat | Claude (claude.ai) | Research on past winners and data sources; the battle plan; a visual HTML prototype (`reference/prototype.html`); concept screenshots; this build kit (`BUILD.md`, `CLAUDE.md`, reference SQL (`supabase/migrations/0001_init.sql`, `supabase/sql/schedule.sql`), test case tables and fixtures) | Plan, spec, screenshots and reference files as a starting point | (fill in: what you rewrote, e.g. "rewrote feed() filters", "wrote our own geotagger from the spec") |
| 2026-09-28 | Yat | Claude Code | Unzip the build kit and run the README-FIRST setup: scaffold with `create-next-app@16.3.6` (TS, App Router, ESLint, Tailwind), copy the kit in (kit `CLAUDE.md` replaces the generated one; generated `AGENTS.md` kept), add `!.env.example` to `.gitignore`, install `maplibre-gl@5.24.0`, rename the package from the temp folder name to `local-pulse`. Then read BUILD.md + concepts and propose an M0 plan (no code) | The unmodified create-next-app output plus the kit files. No app code written by AI | (fill in) |
