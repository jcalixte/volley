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

### Reading a poule code

Codes are positional. `2MB` is level 2, **M**asculine, poule **B** — which is exactly how
FFVB titles it, "NATIONALE 2 MASCULINE - POULE B". Regional codes carry a fourth letter
for the phase: `1MAA` is the _aller_, `1MAR` the _retour_ of the same championship, so the
page folds them into one filter. FFVB does not publish names for its regional poules, so
those keep their code rather than an invented label.

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

Pushes to `main` are picked up by Coolify at https://platform.apoena.dev, which builds
from `docker-compose.yml`: nginx serves the built SPA and proxies `/api` to the Gleam
container over the compose network, so the API is never exposed directly.
