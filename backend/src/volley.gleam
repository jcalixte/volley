import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import mist
import volley/cache.{type Cache}
import volley/ffvb.{type Match}
import volley/ics
import volley/incidents
import volley/salle
import volley/standings.{type Table}
import wisp
import wisp/wisp_mist

const weekend_ttl_seconds = 900

const weekday_ttl_seconds = 21_600

/// Scores come in on weekends, when nearly every match is played.
pub fn ttl_seconds(now: Int) -> Int {
  // Paris is UTC+1 (UTC+2 in summer); an hour off at midnight does not matter.
  // 1970-01-01, day 0, was a Thursday, so 2 is a Saturday and 3 a Sunday.
  case { now + 3600 } / 86_400 % 7 {
    2 | 3 -> weekend_ttl_seconds
    _ -> weekday_ttl_seconds
  }
}

/// Matches and standings are kept per club code; addresses per match sheet.
type Stores {
  Stores(
    matches: Cache(List(Match)),
    standings: Cache(List(Table)),
    addresses: Cache(String),
  )
}

/// Our own club plus the opponents people click through to.
const clubs_kept = 100

const addresses_kept = 1000

pub fn main() {
  wisp.configure_logger()

  let assert Ok(matches) = cache.start(clubs_kept)
  let assert Ok(tables) = cache.start(clubs_kept)
  let assert Ok(addresses) = cache.start(addresses_kept)
  let stores = Stores(matches:, standings: tables, addresses:)
  process.spawn_unlinked(fn() { warm_addresses(stores) })

  let assert Ok(_) =
    handle_request(stores, _)
    |> wisp_mist.handler(secret_key_base())
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

/// Nothing signs a cookie or a session, so a fresh key per boot is safe.
fn secret_key_base() -> String {
  crypto.strong_random_bytes(32) |> bit_array.base16_encode
}

fn handle_request(stores: Stores, req: wisp.Request) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  case wisp.path_segments(req) {
    ["api", "health"] -> wisp.ok()
    ["api", "matches"] -> matches(stores, req)
    ["api", "standings"] -> ranking(stores.standings, req)
    ["api", "calendar.ics"] -> feed(stores.matches, req)
    _ -> wisp.not_found()
  }
}

/// `?club=<FFVB code>` picks another club; without it, ours.
fn club(req: wisp.Request, next: fn(String) -> wisp.Response) -> wisp.Response {
  case wisp.get_query(req) |> list.key_find("club") {
    Error(_) -> next(ffvb.club_code)
    Ok(code) ->
      case ffvb.is_club_code(code) {
        True -> next(code)
        False -> wisp.response(400)
      }
  }
}

fn matches(stores: Stores, req: wisp.Request) -> wisp.Response {
  use code <- club(req)
  let fetch = fn() { ffvb.fetch(code) }
  case current("calendar " <> code, stores.matches, code, fetch) {
    Error(reason) -> failure(reason)
    Ok(#(fetched, fetched_at, stale)) ->
      ffvb.to_json(
        ffvb.club_label(code, fetched),
        fetched,
        fetched_at,
        stale,
        known_address(stores.addresses, _),
      )
      |> wisp.json_response(200)
      |> wisp.set_header("cache-control", "public, max-age=60")
  }
}

fn ranking(store: Cache(List(Table)), req: wisp.Request) -> wisp.Response {
  use code <- club(req)
  case
    current("standings " <> code, store, code, fn() { standings.fetch(code) })
  {
    Error(reason) -> failure(reason)
    Ok(#(fetched, fetched_at, stale)) ->
      standings.to_json(fetched, fetched_at, stale)
      |> wisp.json_response(200)
      |> wisp.set_header("cache-control", "public, max-age=60")
  }
}

fn feed(store: Cache(List(Match)), req: wisp.Request) -> wisp.Response {
  let fetch = fn() { ffvb.fetch(ffvb.club_code) }
  case current("calendar " <> ffvb.club_code, store, ffvb.club_code, fetch) {
    Error(reason) -> failure(reason)
    Ok(#(fetched, _, _)) -> {
      let wanted = case wisp.get_query(req) |> list.key_find("equipe") {
        Ok(keys) ->
          string.split(keys, ",") |> list.filter(fn(key) { key != "" })
        Error(_) -> []
      }
      let selected = case wanted {
        [] -> fetched
        _ ->
          list.filter(fetched, fn(match) {
            list.contains(wanted, ffvb.competition_key(match))
          })
      }

      wisp.response(200)
      |> wisp.set_header("content-type", "text/calendar; charset=utf-8")
      |> wisp.set_header(
        "cache-control",
        "public, max-age=" <> int.to_string(ttl_seconds(now_seconds())),
      )
      |> wisp.string_body(ics.render(
        selected,
        feed_name(selected, wanted),
        timestamp.system_time(),
      ))
    }
  }
}

const address_ttl_seconds = 86_400

fn hall_address(
  store: Cache(String),
  entity: String,
  code: String,
) -> Result(String, Nil) {
  let key = entity <> "/" <> code
  let now = now_seconds()
  let fresh = case cache.read(store, key) {
    Some(entry) ->
      case now - entry.fetched_at < address_ttl_seconds {
        True -> Ok(entry.value)
        False -> Error(Nil)
      }
    None -> Error(Nil)
  }

  use <- result.lazy_or(fresh)
  case salle.fetch_address(entity, code) {
    Ok(address) -> {
      cache.write(store, key, address, now)
      Ok(address)
    }
    Error(reason) -> {
      wisp.log_warning("hall address for " <> key <> ": " <> reason)
      Error(Nil)
    }
  }
}

/// Played matches need no directions, so only fixtures get their address.
fn known_address(store: Cache(String), match: Match) -> Option(String) {
  use <- bool.guard(match.sets != "" || match.venue == "", None)
  cache.read(store, match.entity <> "/" <> match.code)
  |> option.map(fn(entry) { entry.value })
}

const warm_every_ms = 3_600_000

const warm_days_ahead = 14

/// Looks up the hall address of our matches in the coming two weeks, so the
/// page links straight to Google Maps. A link through our redirect route
/// leaves an orphan "You are being redirected" tab once Android hands the
/// Maps URL to the Maps app.
fn warm_addresses(stores: Stores) -> Nil {
  let fetch = fn() { ffvb.fetch(ffvb.club_code) }
  case
    current(
      "calendar " <> ffvb.club_code,
      stores.matches,
      ffvb.club_code,
      fetch,
    )
  {
    Error(_) -> Nil
    Ok(#(fetched, _, _)) -> {
      let now = timestamp.system_time()
      let until = timestamp.add(now, duration.hours(24 * warm_days_ahead))
      salle.due(fetched, iso_date(now), iso_date(until))
      |> list.each(fn(match) {
        hall_address(stores.addresses, match.entity, match.code)
      })
    }
  }
  process.sleep(warm_every_ms)
  warm_addresses(stores)
}

fn iso_date(moment: timestamp.Timestamp) -> String {
  let #(date, _) = timestamp.to_calendar(moment, calendar.utc_offset)
  int.to_string(date.year)
  <> "-"
  <> int.to_string(calendar.month_to_int(date.month))
  |> string.pad_start(2, "0")
  <> "-"
  <> int.to_string(date.day) |> string.pad_start(2, "0")
}

fn feed_name(selected: List(Match), wanted: List(String)) -> String {
  let labels =
    list.filter_map(wanted, fn(key) {
      list.find(selected, fn(match) { ffvb.competition_key(match) == key })
      |> result.map(ffvb.competition_label)
    })
  case labels {
    [] -> "St Maur — tous les matchs"
    _ -> "St Maur — " <> string.join(labels, " + ")
  }
}

fn current(
  document: String,
  store: Cache(value),
  key: String,
  fetch: fn() -> Result(value, String),
) -> Result(#(value, Int, Bool), String) {
  let now = now_seconds()
  let cached = cache.read(store, key)

  case cached {
    Some(entry) ->
      case now - entry.fetched_at < ttl_seconds(now) {
        True -> Ok(#(entry.value, entry.fetched_at, False))
        False -> refresh(document, store, key, fetch, cached, now)
      }
    None -> refresh(document, store, key, fetch, None, now)
  }
}

fn refresh(
  document: String,
  store: Cache(value),
  key: String,
  fetch: fn() -> Result(value, String),
  fallback: Option(cache.Entry(value)),
  now: Int,
) -> Result(#(value, Int, Bool), String) {
  case fetch() {
    Ok(fetched) -> {
      cache.write(store, key, fetched, now)
      Ok(#(fetched, now, False))
    }
    Error(reason) -> {
      let served = case fallback {
        Some(entry) ->
          "a copy " <> int.to_string(now - entry.fetched_at) <> "s old"
        None -> "no copy at all"
      }
      let message =
        document <> " refresh failed, serving " <> served <> ": " <> reason
      incidents.record(document:, served:, reason:)

      case fallback {
        Some(entry) -> {
          wisp.log_warning(message)
          Ok(#(entry.value, entry.fetched_at, True))
        }
        None -> {
          wisp.log_error(message)
          Error(reason)
        }
      }
    }
  }
}

fn failure(reason: String) -> wisp.Response {
  json.object([#("error", json.string(reason))])
  |> json.to_string
  |> wisp.json_response(502)
}

fn now_seconds() -> Int {
  let #(seconds, _) =
    timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
  seconds
}
