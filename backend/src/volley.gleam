import gleam/bit_array
import gleam/crypto
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/time/timestamp
import mist
import volley/cache.{type Cache}
import volley/ffvb.{type Match}
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
    _ -> wisp.not_found()
  }
}

fn matches(store: Cache(List(Match))) -> wisp.Response {
  let now = now_seconds()
  let cached = cache.read(store)

  case cached {
    Some(entry) ->
      case now - entry.fetched_at < ttl_seconds {
        True -> serve(entry.value, entry.fetched_at, False)
        False -> refresh(store, cached, now)
      }
    None -> refresh(store, None, now)
  }
}

fn refresh(
  store: Cache(List(Match)),
  fallback: Option(cache.Entry(List(Match))),
  now: Int,
) -> wisp.Response {
  case ffvb.fetch() {
    Ok(fetched) -> {
      cache.write(store, fetched, now)
      serve(fetched, now, False)
    }
    // Better a calendar from an hour ago than an error page on match day.
    Error(reason) ->
      case fallback {
        Some(entry) -> serve(entry.value, entry.fetched_at, True)
        None -> failure(reason)
      }
  }
}

fn serve(fetched: List(Match), fetched_at: Int, stale: Bool) -> wisp.Response {
  ffvb.to_json(fetched, fetched_at, stale)
  |> wisp.json_response(200)
  |> wisp.set_header("cache-control", "public, max-age=" <> int.to_string(60))
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
