# Homepage redesign (header + match list)

- [x] Hero: next match as a ticket — white date stub with condensed numerals, opponent as focal point
- [x] Countdown chip (Aujourd'hui / Demain / Dans N jours), calendar days, DST-safe + unit test
- [x] Last result line (Victoire/Défaite in words, not colour only)
- [x] Loading skeleton (no layout shift) and empty state when season is over
- [x] Contrast measured: dark tint bg-black/20 keeps /80 text ≥ 6.3:1 (old /15 white tint + /75 text was 3.8:1)
- [x] Barlow Condensed as display face (own @import: coollabs drops 2nd family in one URL)
- [x] Match rows: day, time, score in display numerals
- [x] Tabs scroll inside their box on 360px instead of wrapping; aria-selected
- [x] Tests: header follows team pick, empty state

## Review
vitest 79/79, vue-tsc, oxlint, oxfmt, vite build pass. Not tested in browser.
