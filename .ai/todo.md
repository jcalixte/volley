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
- [x] 7. Gitea repo + push Gitea repo + push (apoena-gitea-repo)
- [x] 8. Coolify app + deploy (apoena-coolify-deploy)
- [x] 9. Verify live

## Review

Built and verified locally:

- 9 Gleam tests (CSV parse, home/away flip, played-vs-fixture, 4-letter poule, cp1252 incl. the 0x80-0x9F range).
- 17 frontend tests (score orientation, aller/retour folding, competition labels, filters, stale banner, API error).
- Smoke-mounted the app against the real 98-match payload: 98 rows, 5 competition
  filters (22+22+18+18+18), French month headings September 2026 - April 2027.
- `pnpm build` clean, `pnpm lint` clean, `pnpm fmt:check` clean.

Not verified locally, and why: the Gleam server itself. `gleam_json` needs OTP 27, this
box has no root and no Docker daemon, so the newest Erlang obtainable was OTP 25
(extracted from debs into `~/.local`). The parse and decode logic runs there and passes;
the HTTP layer does not. It gets verified by the Coolify deploy, which builds on OTP 29.

Blocked at step 7: the Gitea token in this environment is public/read-only and Gitea has
push-to-create disabled, so `git.apoena.dev/julien/volley` cannot be created from here.
SSH push auth works, Coolify API works, DNS resolves. Everything downstream is one step
behind that repo existing.

## Deployed

Live at https://volley.apoena.dev — verified in production, which is also where the Gleam
HTTP layer got its first real run (OTP 29):

- `GET /api/matches` returns 98 matches, `stale: false`.
- windows-1252 survives the round trip: `VANDENBEMDEN FRÉDÉRICK`, no U+FFFD anywhere.
- Cache works: 1.05 s cold, 0.048 s warm.
- TLS verified (`ssl_verify_result 0`).

Coolify app `unkbo5kqlw9csspvqawc1val`, build pack `dockercompose`.

Two Coolify quirks cost a failed deploy each, worth remembering:

- `git_repository` must stay the bare `owner/repo` for GitHub — Coolify prepends
  `https://github.com/` itself. The full-URL PATCH in the apoena-coolify-deploy skill is a
  _Gitea-only_ fix; applying it to GitHub produces
  `https://github.com/https://github.com/jcalixte/volley.git`.
- The compose build pack rejects `domains` and wants
  `docker_compose_domains: [{"name": "web", "domain": "https://…"}]`, and defaults
  `docker_compose_location` to `/docker-compose.yaml` — the `.yml` spelling needs a PATCH.

Repo is on GitHub because `$TEA_TOKEN` in the container is scoped `public-only`, so Gitea
repo creation 403s regardless of consent. Moving it to Gitea later is a remote swap plus a
`git_repository` PATCH to the full `https://git.apoena.dev/julien/volley.git` URL.

## Moved to Gitea

Once a `write:repository` PAT arrived, the repo moved to
https://git.apoena.dev/julien/volley (GitHub kept as a mirror remote).

Coolify would not follow: an app created from a GitHub URL keeps
`source_type: App\Models\GithubApp` forever, and that source prepends
`https://github.com/` to whatever `git_repository` holds — so pointing it at Gitea
produced `https://github.com/https://git.apoena.dev/julien/volley.git`. The
`git_full_url` override is rejected by the API (`This field is not allowed`). The only
fix is to recreate the application with the Gitea URL from the start, which leaves
`source_type: None` and no prefix.

Domain moves between apps need `force_domain_override: true` **in the request body** —
as a query string it 500s.

Live app is now `kiaocrhupwgqd3qvltxsdacl`; the GitHub-sourced one was deleted.
