//// Failed refreshes, appended one line each to a file on a Docker volume. The
//// container's own stdout log dies with the container, and Coolify replaces
//// the container on every deploy — so an outage seen in October would be gone
//// by December. A volume outlives the container, which is what makes the
//// question "how often is FFVB down, and when?" answerable at all.
////
//// One tab-separated line per failure: when, which document, what the visitor
//// got, why.

import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import simplifile

/// Mounted by docker-compose.yml. Absent in local development, where the
/// append fails and is ignored.
pub const path = "/data/upstream-failures.log"

pub fn line(
  at at: Timestamp,
  document document: String,
  served served: String,
  reason reason: String,
) -> String {
  timestamp.to_rfc3339(at, calendar.utc_offset)
  <> "\t"
  <> document
  <> "\t"
  <> served
  <> "\t"
  <> reason
  <> "\n"
}

/// Appends a line, and swallows whatever goes wrong doing it: a volume that
/// did not mount must not turn a served calendar into an error page.
pub fn record(
  document document: String,
  served served: String,
  reason reason: String,
) -> Nil {
  let _ =
    simplifile.append(
      path,
      line(at: timestamp.system_time(), document:, served:, reason:),
    )
  Nil
}
