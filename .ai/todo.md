# Club agenda: click opponent, see their agenda

- [x] backend ffvb: parse/fetch take club code, Match keeps opponent_code, club name derived for other clubs
- [x] backend standings: parse/fetch take club code
- [x] backend volley.gleam: per-club keyed cache (bounded), `?club=` on /api/matches + /api/standings, ICS stays home club
- [x] backend tests updated + new tests (opponent_code, other club parse, club name, code validation)
- [x] frontend lib/club.ts: viewed club from `?club=`; fetchers pass it
- [x] MatchRow / NextMatchCard / Calendar / Summary: opponent name links to `?club=<code>`
- [x] App: other-club mode hides AgendaMenu, home link, filter storage per club; absences + HOME_TOWN only for home
- [x] tests: lib + App
- [x] verify: gleam test, vitest, typecheck, lint, curl

## Review

Shipped in 0c14235. gleam test 53 pass, vitest 102+ pass, vue-tsc + oxlint clean.
Live curl: /api/matches?club=0885362 returns Épinal (108 matches) with opponent codes;
?club=abc gives 400; unknown 7-digit code gives 502; ICS feed unchanged (200).
