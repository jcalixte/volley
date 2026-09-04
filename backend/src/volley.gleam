import gleam/bit_array
import gleam/crypto
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/timestamp
import mist
import volley/cache.{type Cache}
import volley/ffvb.{type Match}
import volley/ics
import wisp
import wisp/wisp_mist

/// How long a fetched calendar is served before we go back to FFVB. Results are
/// entered by hand on match day, so a quarter of an hour is as live as the
/// source itself gets.
const ttl_seconds = 900

pub fn main() {
  wisp.configure_logger()

  let assert Ok(store) = cache.start()

  let assert Ok(_) =
    handle_request(store, _)
    |> wisp_mist.handler(secret_key_base())
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

/// Nothing here signs a cookie or a session — this app is a read-only view of a
/// public calendar — but wisp wants a key, so give it a fresh one per boot.
fn secret_key_base() -> String {
  crypto.strong_random_bytes(32) |> bit_array.base16_encode
}

fn handle_request(store: Cache(List(Match)), req: wisp.Request) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  case wisp.path_segments(req) {
    ["api", "health"] -> wisp.ok()
    ["api", "matches"] -> matches(store)
    ["api", "calendar.ics"] -> feed(store, req)
    _ -> wisp.not_found()
  }
}

fn matches(store: Cache(List(Match))) -> wisp.Response {
  case current(store) {
    Error(reason) -> failure(reason)
    Ok(#(fetched, fetched_at, stale)) ->
      ffvb.to_json(fetched, fetched_at, stale)
      |> wisp.json_response(200)
      |> wisp.set_header("cache-control", "public, max-age=60")
  }
}

/// An iCalendar subscription, optionally narrowed to one championship with
/// `?equipe=<key>`. Calendar clients re-read this on their own schedule, which is
/// the point: a fixture FFVB moves in January reaches a subscriber's phone.
fn feed(store: Cache(List(Match)), req: wisp.Request) -> wisp.Response {
  case current(store) {
    Error(reason) -> failure(reason)
    Ok(#(fetched, _, _)) -> {
      let wanted = wisp.get_query(req) |> list.key_find("equipe")
      let selected = case wanted {
        Error(_) -> fetched
        Ok(key) ->
          list.filter(fetched, fn(match) { ffvb.competition_key(match) == key })
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

fn feed_name(selected: List(Match), wanted: Result(String, Nil)) -> String {
  case selected, wanted {
    [match, ..], Ok(_) -> "St Maur — " <> ffvb.competition_label(match)
    _, _ -> "St Maur — tous les matchs"
  }
}

/// The cached calendar, refreshed when it has aged past the TTL. On a failed
/// refresh the previous copy is served rather than an error — better a calendar
/// from an hour ago than an error page on match day.
fn current(
  store: Cache(List(Match)),
) -> Result(#(List(Match), Int, Bool), String) {
  let now = now_seconds()
  let cached = cache.read(store)

  case cached {
    Some(entry) ->
      case now - entry.fetched_at < ttl_seconds {
        True -> Ok(#(entry.value, entry.fetched_at, False))
        False -> refresh(store, cached, now)
      }
    None -> refresh(store, None, now)
  }
}

fn refresh(
  store: Cache(List(Match)),
  fallback: Option(cache.Entry(List(Match))),
  now: Int,
) -> Result(#(List(Match), Int, Bool), String) {
  case ffvb.fetch() {
    Ok(fetched) -> {
      cache.write(store, fetched, now)
      Ok(#(fetched, now, False))
    }
    Error(reason) ->
      case fallback {
        Some(entry) -> Ok(#(entry.value, entry.fetched_at, True))
        None -> Error(reason)
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
