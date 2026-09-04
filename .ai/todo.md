# volley — St Maur match calendar

Live: https://volley.apoena.dev · Repo: https://git.apoena.dev/julien/volley

## Data source (established)

FFVB exposes a **whole-club, whole-season** CSV in one POST:

```
POST https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier_export_club.php
cnclub=0941410&cal_saison=2026/2027&typ_edition=E&type=RES
```

- club `0941410` = VIE AU GRAND AIR DE ST MAUR
- 98 matches, 3 teams (ST MAUR, ST MAUR 2, ST MAUR 3), 2 entities (ABCCS national, LIIDF Île-de-France)
- `;`-separated, **windows-1252** encoded, header:
  `Entité;Jo;Match;Date;Heure;EQA_no;EQA_nom;EQB_no;EQB_nom;Set;Score;Total;Salle;Arb1;Arb2;`
- `Set`/`Score`/`Total` empty until the match is played → same file carries fixtures _and_ results.

This one endpoint is the whole "keep the calendar up to date" story: no scraping the
frameset, no cron, no database. The backend re-fetches it and the page is current.

## Decisions

|               |                                                                                        |
| ------------- | -------------------------------------------------------------------------------------- |
| App name      | `volley` (scaffolded in place, dir already named it)                                   |
| Domain        | `volley.apoena.dev`                                                                    |
| Backend       | Gleam (wisp + mist) — required: FFVB sends no CORS header, needs POST, is windows-1252 |
| SQLite        | no — in-memory TTL cache + last-good fallback is enough                                |
| Primary color | `#1D4ED8` (contrast-checked before use)                                                |
| Favicon       | Tabler `ball-volleyball`                                                               |

## Plan

- [x] 1. Scaffold SPA (apoena-spa-scaffold) — real first screen: the match list
- [x] 2. Gleam backend (apoena-gleam-backend), no SQLite
- [x] 3. `/api/matches` — POST upstream, decode cp1252, parse CSV, emit JSON
- [x] 4. Cache actor: 15 min TTL, serve stale on upstream failure
- [x] 5. Front: group by month, team filter, home/away, next-match highlight, played scores
- [x] 6. README
- [ ] 7. Gitea repo + push (apoena-gitea-repo)
- [ ] 8. Coolify app + deploy (apoena-coolify-deploy)
- [ ] 9. Verify live

## Review

_(filled at the end)_
