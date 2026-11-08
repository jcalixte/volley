//// Failed upstream refreshes, one line each, on a Docker volume: Coolify
//// replaces the container, and its stdout log, on every deploy.

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

/// Ignores write errors: a volume that did not mount must not turn a served
/// calendar into an error page.
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
