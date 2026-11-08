# Calendar view redesign (from screenshot)

- [x] Fix jammed chip text ("16:00REIMS", "ACBB 2🇯🇵"): flex + gap instead of literal spaces
- [x] Weekend columns 3fr, weekdays 1fr rails (274 Sat + 97 Sun vs 13 weekday matches/season)
- [x] Home/away not by colour only: home icon on home chips, legend explains it
- [x] Several teams: poule code on chip + legend (colour no longer the only cue)
- [x] Flag pinned at chip end, never truncated
- [x] Header: month title as focal point, 44px chevron nav buttons, "Aujourd'hui" next to title
- [x] Tests updated (dropped class-string test, fixed jammed-text assertion)

## Review
vitest 75/75, vue-tsc, oxlint, oxfmt pass. Not tested in browser.
