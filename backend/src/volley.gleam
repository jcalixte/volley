import gleam/bit_array
import gleam/crypto
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp
import mist
import volley/cache.{type Cache}
import volley/ffvb.{type Match}
import volley/ics
import volley/incidents
import volley/standings.{type Table}
import wisp
import wisp/wisp_mist

const ttl_seconds = 900

type Stores {
  Stores(matches: Cache(List(Match)), standings: Cache(List(Table)))
}

pub fn main() {
  wisp.configure_logger()

  let assert Ok(matches) = cache.start()
  let assert Ok(tables) = cache.start()
  let stores = Stores(matches:, standings: tables)

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
    ["api", "matches"] -> matches(stores.matches)
    ["api", "standings"] -> ranking(stores.standings)
    ["api", "calendar.ics"] -> feed(stores.matches, req)
    _ -> wisp.not_found()
  }
}

fn matches(store: Cache(List(Match))) -> wisp.Response {
  case current("calendar", store, ffvb.fetch) {
    Error(reason) -> failure(reason)
    Ok(#(fetched, fetched_at, stale)) ->
      ffvb.to_json(fetched, fetched_at, stale)
      |> wisp.json_response(200)
      |> wisp.set_header("cache-control", "public, max-age=60")
  }
}

fn ranking(store: Cache(List(Table))) -> wisp.Response {
  case current("standings", store, standings.fetch) {
    Error(reason) -> failure(reason)
    Ok(#(fetched, fetched_at, stale)) ->
      standings.to_json(fetched, fetched_at, stale)
      |> wisp.json_response(200)
      |> wisp.set_header("cache-control", "public, max-age=60")
  }
}

fn feed(store: Cache(List(Match)), req: wisp.Request) -> wisp.Response {
  case current("calendar", store, ffvb.fetch) {
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
      |> wisp.set_header("cache-control", "public, max-age=900")
      |> wisp.string_body(ics.render(
        selected,
        feed_name(selected, wanted),
        timestamp.system_time(),
      ))
    }
  }
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
  fetch: fn() -> Result(value, String),
) -> Result(#(value, Int, Bool), String) {
  let now = now_seconds()
  let cached = cache.read(store)

  case cached {
    Some(entry) ->
      case now - entry.fetched_at < ttl_seconds {
        True -> Ok(#(entry.value, entry.fetched_at, False))
        False -> refresh(document, store, fetch, cached, now)
      }
    None -> refresh(document, store, fetch, None, now)
  }
}

fn refresh(
  document: String,
  store: Cache(value),
  fetch: fn() -> Result(value, String),
  fallback: Option(cache.Entry(value)),
  now: Int,
) -> Result(#(value, Int, Bool), String) {
  case fetch() {
    Ok(fetched) -> {
      cache.write(store, fetched, now)
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
