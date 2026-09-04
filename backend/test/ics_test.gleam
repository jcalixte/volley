import gleam/bit_array
import gleam/list
import gleam/string
import gleeunit/should
import gleam/time/timestamp
import volley/ffvb
import volley/ics

const sample = "header
ABCCS;01;2MB004;2026-09-27;16:00;0941410;VIE AU GRAND AIR DE ST MAUR;0758425;PARIS VOLLEY CLUB;;;;BROSSOLETTE;GARRAUT LORENZO;;
ABCCS;02;2MB009;2026-10-04;14:00;0757777;PUC VOLLEY-BALL 3;0941410;VIE AU GRAND AIR DE ST MAUR;3-1;25-20,25-18,22-25,25-19;4;PIERRE CHARPY;;;
"

fn render() -> String {
  ics.render(ffvb.parse(sample), "St Maur", timestamp.from_unix_seconds(1_788_500_000))
}

fn lines() -> List(String) {
  render() |> string.split("\r\n")
}

pub fn wraps_the_events_in_a_calendar_test() {
  let output = lines()
  output |> list.first |> should.equal(Ok("BEGIN:VCALENDAR"))
  output |> list.contains("END:VCALENDAR") |> should.be_true
  output |> list.count(fn(l) { l == "BEGIN:VEVENT" }) |> should.equal(2)
}

/// Every line must end CRLF, including the last one.
pub fn ends_every_line_with_crlf_test() {
  render() |> string.ends_with("END:VCALENDAR\r\n") |> should.be_true
  render() |> string.contains("\n\n") |> should.be_false
}

/// Times are French local. Shipping a bare UTC offset would be an hour wrong for
/// half the season, so the feed carries the Europe/Paris rules.
pub fn anchors_times_to_the_paris_timezone_test() {
  let output = lines()
  output |> list.contains("BEGIN:VTIMEZONE") |> should.be_true
  output |> list.contains("TZID:Europe/Paris") |> should.be_true
  output
  |> list.contains("DTSTART;TZID=Europe/Paris:20260927T160000")
  |> should.be_true
}

pub fn gives_each_match_a_stable_uid_test() {
  lines()
  |> list.contains("UID:2MB004@volley.apoena.dev")
  |> should.be_true
}

pub fn names_the_home_side_first_test() {
  lines()
  |> list.contains("SUMMARY:VIE AU GRAND AIR DE ST MAUR – PARIS VOLLEY CLUB")
  |> should.be_true
}

pub fn appends_the_score_once_a_match_is_played_test() {
  lines()
  |> list.contains("SUMMARY:PUC VOLLEY-BALL 3 – VIE AU GRAND AIR DE ST MAUR (3-1)")
  |> should.be_true
}

pub fn carries_the_venue_as_the_location_test() {
  lines() |> list.contains("LOCATION:BROSSOLETTE") |> should.be_true
}

/// A duration avoids the date arithmetic an explicit DTEND would need for a
/// fixture that runs past midnight.
pub fn gives_each_match_a_duration_test() {
  lines() |> list.contains("DURATION:PT2H") |> should.be_true
}

/// Commas separate values in RFC 5545, so a set-by-set score must be escaped or
/// the description silently truncates.
pub fn escapes_reserved_characters_test() {
  let commas =
    lines()
    |> list.filter(fn(l) { string.contains(l, "25-20") })
  commas |> list.is_empty |> should.be_false
  commas
  |> list.all(fn(l) { !string.contains(l, "25-20,") })
  |> should.be_true
}

/// Content lines are capped at 75 octets; longer ones continue with a leading
/// space. Octets, not characters: the description carries "Journée" and "·",
/// which cost two bytes each, so a grapheme count silently overruns.
pub fn folds_long_lines_to_75_octets_test() {
  lines()
  |> list.all(fn(l) { bit_array.byte_size(bit_array.from_string(l)) <= 75 })
  |> should.be_true
}

/// Folding must never split a character in half.
pub fn folding_keeps_multibyte_characters_whole_test() {
  render() |> string.contains("Journée") |> should.be_true
  render() |> string.contains("\u{FFFD}") |> should.be_false
}

pub fn renders_an_empty_calendar_without_events_test() {
  let output =
    ics.render([], "Vide", timestamp.from_unix_seconds(0))
    |> string.split("\r\n")
  output |> list.contains("BEGIN:VEVENT") |> should.be_false
  output |> list.contains("END:VCALENDAR") |> should.be_true
}
