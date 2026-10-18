import gleam/time/timestamp
import gleeunit/should
import simplifile
import volley/incidents

/// 2026-10-17 20:30 UTC, a Saturday evening.
const saturday_evening = 1_792_269_000

pub fn line_is_one_tab_separated_record_test() {
  incidents.line(
    at: timestamp.from_unix_seconds(saturday_evening),
    document: "calendar",
    served: "a copy 7200s old",
    reason: "could not reach www.ffvbbeach.org",
  )
  |> should.equal(
    "2026-10-17T20:30:00Z\tcalendar\ta copy 7200s old\tcould not reach www.ffvbbeach.org\n",
  )
}

pub fn record_appends_rather_than_overwrites_test() {
  let path = "/tmp/volley_incidents_test.log"
  let _ = simplifile.delete(path)

  let _ = simplifile.append(path, "first\n")
  let _ = simplifile.append(path, "second\n")

  simplifile.read(path) |> should.equal(Ok("first\nsecond\n"))
  let _ = simplifile.delete(path)
}

/// A missing volume must cost a log line, not the response.
pub fn record_survives_an_unwritable_path_test() {
  incidents.record(
    document: "standings",
    served: "no copy at all",
    reason: "upstream returned HTTP 503",
  )
  |> should.equal(Nil)
}
