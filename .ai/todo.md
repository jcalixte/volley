# Itinéraire: real hall address (Boulogne bug)

- [x] Root cause: FFVB CSV gives hall name only ("COUCHOT"), guess "COUCHOT ACBB" lands on wrong place
- [x] backend `volley/salle.gleam`: read address from FFVB match sheet PDF (fiche_match_ffvb.php), FFI inflates Flate streams
- [x] route `/api/salle/:entity/:code[/itineraire]?q=<guess>` 303 to Google Maps, 1-day in-memory cache, fallback to `q`
- [x] frontend `mapsUrl` / `directionsUrl` point to route
- [x] tests: gleam (salle_test) + vitest

## Review

- gleam test 42 passed; vitest 87 passed; vue-tsc, oxlint, oxfmt clean.
- Local backend curl: 2MB042 -> "COUCHOT, 2 RUE COUCHOT, 92100 BOULOGNE BILLANCOURT"; no-address match falls back to `q`; bad codes 404.
- Not tested in browser.
