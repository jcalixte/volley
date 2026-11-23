//// FFVB's club calendar export: every match of every club team for the season,
//// fixtures and results in one file. Set/Score stay empty until a match is played.

import gleam/bool
import gleam/dict
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import volley/cp1252

pub const club_code = "0941410"

pub const club_name = "VIE AU GRAND AIR DE ST MAUR"

pub const season = "2026/2027"

const host = "www.ffvbbeach.org"

const export_path = "/ffvbapp/resu/vbspo_calendrier_export_club.php"

pub type Match {
  Match(
    code: String,
    poule: String,
    entity: String,
    round: String,
    date: String,
    time: String,
    team: String,
    opponent: String,
    /// FFVB's 7-digit club code; empty when the slot has no opponent (a bye).
    opponent_code: String,
    at_home: Bool,
    venue: String,
    sets: String,
    score: String,
    referees: List(String),
  )
}

/// FFVB club codes are 7 digits, e.g. "0941410".
pub fn is_club_code(text: String) -> Bool {
  string.length(text) == 7
  && list.all(string.to_graphemes(text), fn(char) {
    string.contains("0123456789", char)
  })
}

pub fn fetch(club: String) -> Result(List(Match), String) {
  let form =
    "cnclub=" <> club <> "&cal_saison=" <> season <> "&typ_edition=E&type=RES"

  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> request.set_host(host)
    |> request.set_path(export_path)
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> request.set_body(<<form:utf8>>)

  let config =
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.timeout(20_000)

  use response <- result.try(
    httpc.dispatch_bits(config, req)
    |> result.replace_error("could not reach " <> host),
  )

  case response.status {
    200 ->
      case parse(cp1252.decode(response.body), club) {
        [] -> Error("upstream returned no matches")
        matches -> Ok(matches)
      }
    status -> Error("upstream returned HTTP " <> string.inspect(status))
  }
}

pub fn parse(csv: String, club: String) -> List(Match) {
  csv
  |> string.split("\n")
  |> list.drop(1)
  |> list.filter_map(parse_row(_, club))
}

fn parse_row(line: String, club: String) -> Result(Match, Nil) {
  case line |> string.trim |> string.split(";") {
    [
      entity,
      round,
      code,
      date,
      time,
      home_code,
      home,
      away_code,
      away,
      sets,
      score,
      _total,
      venue,
      referee_a,
      referee_b,
      ..
    ] -> {
      let at_home = home_code == club
      use <- guard_ours(at_home || away_code == club)
      let #(team, opponent, opponent_code) = case at_home {
        True -> #(home, away, away_code)
        False -> #(away, home, home_code)
      }
      Ok(Match(
        code:,
        poule: string.drop_end(code, 3),
        entity:,
        round:,
        date:,
        time:,
        team:,
        opponent:,
        opponent_code:,
        at_home:,
        venue:,
        sets: sets |> string.trim |> string.replace("/", "-"),
        score:,
        referees: [referee_a, referee_b] |> list.filter(fn(r) { r != "" }),
      ))
    }
    _ -> Error(Nil)
  }
}

fn guard_ours(
  ours: Bool,
  next: fn() -> Result(Match, Nil),
) -> Result(Match, Nil) {
  case ours {
    True -> next()
    False -> Error(Nil)
  }
}

// FFVB poule codes are positional: level, gender, group, and — in the regional
// championships only — a phase letter, A for aller and R for retour. The two
// phases are one championship, so they share a key.
pub fn competition_key(match: Match) -> String {
  case string.length(match.poule) > 3 {
    True -> string.slice(match.poule, 0, 3)
    False -> match.poule
  }
}

/// For a national poule this reproduces FFVB's own title, e.g. 2MB becomes
/// "Nationale 2 Masculine · Poule B". FFVB publishes no names for its regional
/// poules, so those keep their code rather than an invented label.
pub fn competition_label(match: Match) -> String {
  let gender = case string.slice(match.poule, 1, 1) {
    "M" -> "Masculine"
    _ -> "Féminine"
  }
  case match.entity {
    "ABCCS" ->
      "Nationale "
      <> string.slice(match.poule, 0, 1)
      <> " "
      <> gender
      <> " · Poule "
      <> string.slice(match.poule, 2, 1)
    _ -> "Île-de-France " <> gender <> " · " <> competition_key(match)
  }
}

pub fn poule_url(match: Match) -> String {
  "https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier.php?saison="
  <> string.replace(season, "/", "%2F")
  <> "&codent="
  <> match.entity
  <> "&poule="
  <> match.poule
}

/// FFVB's export carries no club name, only each team's: the national poule
/// says "EPINAL GOLBEY VOLLEY-BALL (EGVB)", a regional one "EPINAL GOLBEY 3".
/// The name the club plays under most often is the best stand-in.
pub fn club_label(club: String, matches: List(Match)) -> String {
  use <- bool.guard(club == club_code, club_name)
  matches
  |> list.fold(dict.new(), fn(counts, match) {
    dict.upsert(counts, match.team, fn(count) { option.unwrap(count, 0) + 1 })
  })
  |> dict.to_list
  |> list.sort(fn(a, b) {
    let #(_, first) = a
    let #(_, second) = b
    int.compare(second, first)
  })
  |> list.first
  |> result.map(fn(pair) { pair.0 })
  |> result.unwrap(club)
}

/// `address` is the hall's postal address, when it is already known.
pub fn to_json(
  club: String,
  matches: List(Match),
  fetched_at: Int,
  stale: Bool,
  address: fn(Match) -> option.Option(String),
) -> String {
  json.object([
    #("club", json.string(club)),
    #("season", json.string(season)),
    #("fetchedAt", json.int(fetched_at)),
    #("stale", json.bool(stale)),
    #("matches", json.array(matches, match_json(_, address))),
  ])
  |> json.to_string
}

fn match_json(
  match: Match,
  address: fn(Match) -> option.Option(String),
) -> Json {
  json.object([
    #("code", json.string(match.code)),
    #("poule", json.string(match.poule)),
    #("competitionKey", json.string(competition_key(match))),
    #("competition", json.string(competition_label(match))),
    #("ffvbUrl", json.string(poule_url(match))),
    #("entity", json.string(match.entity)),
    #("round", json.string(match.round)),
    #("date", json.string(match.date)),
    #("time", json.string(match.time)),
    #("team", json.string(match.team)),
    #("opponent", json.string(match.opponent)),
    #("opponentCode", json.string(match.opponent_code)),
    #("atHome", json.bool(match.at_home)),
    #("venue", json.string(match.venue)),
    #("address", json.nullable(address(match), json.string)),
    #("sets", json.string(match.sets)),
    #("score", json.string(match.score)),
    #("referees", json.array(match.referees, json.string)),
  ])
}
