# Case tables

Expected results for the pure-logic modules (BUILD.md sections in brackets). Vitest tests load these files directly.

| File | Module | Source |
|---|---|---|
| `levels.json` | `lib/levels.ts` [§16.6] | Switch points measured in the prototype |
| `geotag.json` | `_shared/logic/geotag.ts` [§12] | Real Sept 26 headlines + synthetic edge cases; all 24 pass with the §12 rules |
| `politics.json` | `_shared/logic/politics.ts` [§11.3] | Plus fixture counts in the file's note |
| `severity.json` | `_shared/logic/severity.ts` [§11.1] | NWS events from the Sept 24-26 fixtures + other sources |
| `factcheck.json` | `_shared/logic/factcheck.ts` [§13] | Includes NWS's colon-less "559 PM" times |
| `dedupe.json` | `_shared/logic/dedupe.ts` [§11.5] | Exact word lists; one expected merge on the fixtures |

## Scores to record

| Check | Target | Result | Date |
|---|---|---|---|
| Geotag: 100 hand-checked headlines | 95% | | |
| AI summaries: 30 archived notices | 28/30, every failure caught | | |
