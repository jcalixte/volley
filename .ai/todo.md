# Redesign of the remaining tabs (À venir, Résultats, Toute la saison, Synthèse)

Direction: same match-day ticket language as header, calendar and ranking — Barlow
Condensed numerals and names, team colour as the one recurring mark.

- [x] MatchRow: team colour stripe, opponent in display face (wraps, no truncate),
      Domicile badge with home icon, V/D chip with text (not colour alone), meta at /70
- [x] App list: month headings in display face with match count, per-tab empty message
- [x] Résultats: season record strip (victoires / défaites / sets) above the list
- [x] Tab bar: 44px targets
- [x] PrintSummary: display-face heading and team headers, printer icon on 44px button,
      month divider rows, flag with flex gap (no literal space)
- [x] Tests for record strip and month divider rows

## Review
vitest 85/85, vue-tsc, oxlint, oxfmt, vite build pass. Not tested in browser.
