# volley

Every match of **Vie au Grand Air de Saint-Maur** — all teams, all competitions — on one page.

Deployed at https://volley.apoena.dev

## Where the data comes from

FFVB publishes results through a frameset that shows one _poule_ at a time, so a club
with five championships is spread over five pages. Behind that frameset sits an export
endpoint that returns the club's entire season in a single request:

```
POST https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier_export_club.php
cnclub=0941410&cal_saison=2026/2027&typ_edition=E&type=RES
```

It answers with a `;`-separated, windows-1252 file — 98 rows for 2026/2027 — carrying
fixtures and results in the same shape: the `Set` and `Score` columns are empty until a
match is played, then filled in. Re-fetching that one file is the whole update mechanism.
There is no scraper, no scheduled job and no database.

The backend fetches it at most once every 15 minutes, and keeps the last good response
indefinitely so that an FFVB outage degrades to a slightly old calendar rather than an
error page.

## Layout

```
src/            Vue 3 SPA — the page
backend/        Gleam (wisp + mist) — GET /api/matches
nginx.conf      serves the SPA and proxies /api to the backend
```

`GET /api/matches` returns:

```json
{
  "club": "VIE AU GRAND AIR DE ST MAUR",
  "season": "2026/2027",
  "fetchedAt": 1788507000,
  "stale": false,
  "matches": [
    {
      "code": "2MB004",
      "poule": "2MB",
      "entity": "ABCCS",
      "round": "01",
      "date": "2026-09-27",
      "time": "16:00",
      "team": "VIE AU GRAND AIR DE ST MAUR",
      "opponent": "PARIS VOLLEY CLUB",
      "atHome": true,
      "venue": "BROSSOLETTE",
      "sets": "",
      "score": "",
      "referees": ["GARRAUT LORENZO"]
    }
  ]
}
```

`stale: true` means FFVB could not be reached and this is the last good copy.

`GET /api/calendar.ics` returns the same fixtures as an iCalendar feed, narrowed to one
championship with `?equipe=<competitionKey>`. It is meant to be **subscribed** to, not
downloaded: FFVB moves fixtures during the season, and a subscription picks that up where
an imported file stays wrong. Events carry `TZID=Europe/Paris` with the DST rules (a fixed
offset would be an hour out for half the season), a stable `UID` per match code so a moved
fixture updates in place rather than duplicating, and `DURATION:PT2H` instead of a `DTEND`.

### Reading a poule code

The backend derives the competition key, label and FFVB link and ships them in the JSON,
so the page renders what it is given rather than re-deriving the same rules in TypeScript.

Codes are positional. `2MB` is level 2, **M**asculine, poule **B** — which is exactly how
FFVB titles it, "NATIONALE 2 MASCULINE - POULE B". Regional codes carry a fourth letter
for the phase: `1MAA` is the _aller_, `1MAR` the _retour_ of the same championship, so the
page folds them into one filter. FFVB does not publish names for its regional poules, so
those keep their code rather than an invented label.

The page opens on whichever championship you last picked, and puts it in the URL as
`?equipe=2MB`, so a link to one team's fixtures can be shared. A remembered code that no
longer exists — poules are renumbered between seasons — falls back to showing every team.

Each venue links to a Google Maps search. FFVB publishes the hall's street address only
inside the per-match PDF, so the page searches for the hall name plus its town instead —
the name alone is ambiguous ("PALAIS DES SPORTS", "GYMNASE MUNICIPAL"), but the host club
names the town, and home games are always in Saint-Maur.

Fixtures played while a regular is away carry a flag: the setter is in Japan from
17 November 2026 to 15 February 2027, so every match in that window shows 🇯🇵. The window
lives in `src/lib/absences.ts` as two `YYYY-MM-DD` strings compared against the FFVB date
string, which keeps the boundary days unambiguous — no timezone is involved.

Team names are not a usable grouping key: two different squads both appear as
"VIE AU GRAND AIR DE ST MAUR", and "… 2" plays both a men's and a women's championship.
The poule is the identity.

## Develop

```bash
pnpm install
pnpm dev        # frontend on :5173, proxying /api to :8000
pnpm test       # vitest
pnpm lint       # oxlint  (pnpm lint:fix to autofix)
pnpm fmt        # oxfmt   (pnpm fmt:check to verify only)
pnpm build      # vue-tsc + vite build

cd backend
gleam test
gleam run       # api on :8000
```

Requires Erlang/OTP 27 or newer (`gleam_json` uses the OTP `json` module).

## Deploy

Source lives at https://git.apoena.dev/julien/volley (mirrored to
https://github.com/jcalixte/volley). Pushes to `main` fire a webhook to
Coolify at https://platform.apoena.dev, which builds from `docker-compose.yml`: nginx
serves the built SPA and proxies `/api` to the Gleam container over the compose network,
so the API is never exposed directly. Neither container publishes a host port — Coolify's
proxy owns `:80` and routes to `web`.
