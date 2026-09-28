# Local Pulse build kit

Everything Claude Code needs to build Local Pulse, in one folder.

| Path | What it is |
|---|---|
| `BUILD.md` | The full build spec: stack, database, every data source, rules, screens, design tokens, tests, milestones |
| `CLAUDE.md` | Standing rules for Claude Code, including which modules you two must write yourselves (contest AI rule) |
| `docs/concepts/` | 14 concept screenshots and GIFs of every level, rendered from the prototype |
| `docs/AI_USE_LOG.md` | Start logging AI help from day one (first row already filled in) |
| `reference/prototype.html` | Working visual prototype. Open in Chrome; add `#world`, `#region`, `#state`, `#county`, `#local`, `#local-alerts` or `#away` to the address, and `?safe=59,34` to fake an installed iPhone |
| `supabase/migrations/0001_init.sql` | Reference schema, security rules, `feed()` (tested on Postgres 16 + PostGIS) |
| `supabase/sql/schedule.sql` | Cron jobs. Not a migration: run once by hand at the end of setup (BUILD.md §14) |
| `tests/cases/` | Expected results for levels, geotagging, the politics filter, severity, the AI fact check and duplicates |
| `tests/fixtures/` | Real feed samples captured Sept 26, 2026 |
| `tests/sql/` | Sample rows and expected `feed()` results |
| `data/` | Census Gazetteer (Arizona places) and the four boundary files the prototype uses |
| `.env.example` | Environment variable template |

## Start (about 15 minutes, by hand)

1. Create an empty GitHub repo named `local-pulse` and clone it next to this kit folder.
2. In the folder that contains the clone, scaffold the app into it:
   ```bash
   npx create-next-app@latest local-pulse --yes --ts --app --eslint --tailwind --no-src-dir --import-alias "@/*" --use-npm
   ```
   If it refuses because the folder isn't empty, scaffold into `local-pulse-tmp` and move everything (including dot files) into `local-pulse`.
3. Copy everything from this kit into `local-pulse`, **replacing** the `CLAUDE.md` that create-next-app wrote (ours imports its `AGENTS.md`, so keep that file).
4. Add `!.env.example` as the last line of `.gitignore` (the generated file ignores every `.env*` file).
5. Install MapLibre pinned to v5: `npm install maplibre-gl@5.24.0` (v6 has breaking changes).
6. Commit ("Scaffold + build kit"), push, and import the repo in Vercel.
7. Open Claude Code in `local-pulse` and send:
   > Read CLAUDE.md and BUILD.md and look at every image in docs/concepts. Then propose a plan for milestone M0 only. Don't write code yet.
8. Work one milestone at a time (BUILD.md §27). Log AI help in `docs/AI_USE_LOG.md` after every session.
