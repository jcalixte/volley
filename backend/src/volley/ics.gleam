//// iCalendar feed (RFC 5545) of the club's fixtures.

import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import volley/ffvb.{type Match}

const domain = "volley.apoena.dev"

/// Match times are French local time: ship the Europe/Paris rules, not a fixed
/// offset that breaks at the DST changeover.
const paris_timezone = "BEGIN:VTIMEZONE
TZID:Europe/Paris
BEGIN:DAYLIGHT
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
TZNAME:CEST
DTSTART:19700329T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
TZNAME:CET
DTSTART:19701025T030000
RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
END:STANDARD
END:VTIMEZONE"

pub fn render(matches: List(Match), name: String, now: Timestamp) -> String {
  let stamp = utc_stamp(now)

  [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//" <> domain <> "//Calendrier FFVB//FR",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "X-WR-CALNAME:" <> escape(name),
    "X-WR-TIMEZONE:Europe/Paris",
    // Both spellings exist in the wild; Apple reads the first, Google the second.
    "REFRESH-INTERVAL;VALUE=DURATION:PT6H",
    "X-PUBLISHED-TTL:PT6H",
    paris_timezone,
    ..list.flat_map(matches, event(_, stamp))
  ]
  |> list.append(["END:VCALENDAR"])
  |> list.flat_map(string.split(_, "\n"))
  |> list.map(fold)
  |> string.join("\r\n")
  |> string.append("\r\n")
}

fn event(match: Match, stamp: String) -> List(String) {
  [
    "BEGIN:VEVENT",
    "UID:" <> match.code <> "@" <> domain,
    "DTSTAMP:" <> stamp,
    "DTSTART;TZID=Europe/Paris:" <> start(match),
    "DURATION:PT2H",
    "SUMMARY:" <> escape(summary(match)),
    "LOCATION:" <> escape(match.venue),
    "DESCRIPTION:" <> escape(description(match)),
    "URL:" <> ffvb.poule_url(match),
    "END:VEVENT",
  ]
}

fn summary(match: Match) -> String {
  let #(home, away) = case match.at_home {
    True -> #(match.team, match.opponent)
    False -> #(match.opponent, match.team)
  }
  let title = home <> " – " <> away
  case match.sets {
    "" -> title
    sets -> title <> " (" <> sets <> ")"
  }
}

fn description(match: Match) -> String {
  [
    ffvb.competition_label(match),
    "Journée " <> match.round,
    case match.at_home {
      True -> "À domicile"
      False -> "À l'extérieur"
    },
    case match.score {
      "" -> ""
      score -> "Score : " <> score
    },
    case match.referees {
      [] -> ""
      referees -> "Arbitres : " <> string.join(referees, ", ")
    },
    ffvb.poule_url(match),
  ]
  |> list.filter(fn(line) { line != "" })
  |> string.join("\n")
}

fn start(match: Match) -> String {
  let date = string.replace(match.date, "-", "")
  let time = string.replace(match.time, ":", "")
  date <> "T" <> pad_time(time) <> "00"
}

fn pad_time(time: String) -> String {
  case string.length(time) {
    4 -> time
    _ -> "0000"
  }
}

fn utc_stamp(now: Timestamp) -> String {
  let #(date, time) = timestamp.to_calendar(now, calendar.utc_offset)
  pad(date.year, 4)
  <> pad(calendar.month_to_int(date.month), 2)
  <> pad(date.day, 2)
  <> "T"
  <> pad(time.hours, 2)
  <> pad(time.minutes, 2)
  <> pad(time.seconds, 2)
  <> "Z"
}

fn pad(value: Int, width: Int) -> String {
  int.to_string(value) |> string.pad_start(width, "0")
}

/// RFC 5545 reserves these inside a TEXT value.
fn escape(value: String) -> String {
  value
  |> string.replace("\\", "\\\\")
  |> string.replace(";", "\\;")
  |> string.replace(",", "\\,")
  |> string.replace("\n", "\\n")
}

/// RFC 5545 caps content lines at 75 octets, not characters, so this counts
/// UTF-8 bytes and breaks only between whole characters. A continuation line
/// starts with a space, so segments stay under the limit with room for it.
const max_segment_bytes = 73

fn fold(line: String) -> String {
  case byte_size(line) <= max_segment_bytes {
    True -> line
    False -> {
      let #(head, rest) =
        take_bytes(string.to_graphemes(line), max_segment_bytes, "")
      head <> "\r\n " <> fold(rest)
    }
  }
}

fn take_bytes(
  graphemes: List(String),
  budget: Int,
  taken: String,
) -> #(String, String) {
  case graphemes {
    [] -> #(taken, "")
    [grapheme, ..rest] -> {
      let size = byte_size(grapheme)
      case size > budget {
        True -> #(taken, string.concat(graphemes))
        False -> take_bytes(rest, budget - size, taken <> grapheme)
      }
    }
  }
}

fn byte_size(value: String) -> Int {
  bit_array.byte_size(bit_array.from_string(value))
}
