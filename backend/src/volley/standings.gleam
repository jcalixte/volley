//// FFVB's "Classements des Equipes du Club" page. One GET returns the standing
//// table of every poule the club plays in — the same bargain as the calendar
//// export, one request for the whole club, so the ranking needs no extra
//// scraping of the per-poule frameset.
////
//// The answer is a windows-1252 HTML page built by hand in PHP, so it is read
//// positionally rather than with a DOM: a `<tr>` holding `titrepoule` opens a
//// table, a `<tr>` holding the magnifier icon is one team's line, and the
//// nineteen first `<td>`s of that line are the columns FFVB prints.

import gleam/bool
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/result
import gleam/string
import volley/cp1252
import volley/ffvb

const host = "www.ffvbbeach.org"

const standings_path = "/ffvbapp/resu/planning_club_class.php"

/// Marks the `<tr>` that titles a poule, e.g. "2MB - NATIONALE 2 MASCULINE - POULE B".
const title_marker = "titrepoule"

/// Every team line carries a magnifier linking to its fixtures; nothing else does.
const row_marker = "ico_spo_loupe"

pub type Row {
  Row(
    rank: Int,
    team: String,
    /// FFVB stamps each line with the club it belongs to, so our own teams are
    /// known exactly rather than guessed from a name — the departmental poule
    /// calls us "VGA ST MAUR 3" where the national one spells the club out.
    ours: Bool,
    points: Int,
    played: Int,
    won: Int,
    lost: Int,
    forfeits: Int,
    sets_won: Int,
    sets_lost: Int,
    /// Ratios stay strings: FFVB prints "MAX" when no set has been conceded.
    set_ratio: String,
    points_won: Int,
    points_lost: Int,
    point_ratio: String,
  )
}

pub type Table {
  Table(
    key: String,
    title: String,
    level: String,
    entity: String,
    rows: List(Row),
  )
}

pub fn fetch() -> Result(List(Table), String) {
  let req =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_scheme(http.Https)
    |> request.set_host(host)
    |> request.set_path(standings_path)
    |> request.set_query([#("cnclub", ffvb.club_code)])
    |> request.set_body(<<>>)

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
      case parse(cp1252.decode(response.body)) {
        [] -> Error("upstream returned no standings")
        tables -> Ok(tables)
      }
    status -> Error("upstream returned HTTP " <> string.inspect(status))
  }
}

pub fn parse(html: String) -> List(Table) {
  string.split(html, "<tr")
  |> list.fold([], absorb)
  |> list.reverse
  |> list.map(fn(table) { Table(..table, rows: list.reverse(table.rows)) })
}

/// Rows belong to the table opened most recently, so the list is built head-first
/// and turned around at the end.
fn absorb(tables: List(Table), chunk: String) -> List(Table) {
  case string.contains(chunk, title_marker), tables {
    True, _ ->
      case header(chunk) {
        Ok(table) -> [table, ..tables]
        Error(_) -> tables
      }
    False, [current, ..rest] ->
      case row(chunk) {
        Ok(row) -> [extend(current, chunk, row), ..rest]
        Error(_) -> tables
      }
    False, [] -> tables
  }
}

fn header(chunk: String) -> Result(Table, Nil) {
  case cells(chunk) {
    [level, title, ..] -> {
      use #(key, name) <- result.try(string.split_once(title, " - "))
      Ok(
        Table(
          key: string.trim(key),
          title: string.trim(name),
          level:,
          entity: "",
          rows: [],
        ),
      )
    }
    _ -> Error(Nil)
  }
}

/// The entity code only exists on the team lines, inside the hidden form that
/// links each one to its fixtures, so the table takes it from its first row.
fn extend(table: Table, chunk: String, row: Row) -> Table {
  let entity = case table.entity {
    "" -> hidden(chunk, "codent") |> result.unwrap("")
    known -> known
  }
  Table(..table, entity:, rows: [row, ..table.rows])
}

fn row(chunk: String) -> Result(Row, Nil) {
  use <- bool.guard(!string.contains(chunk, row_marker), Error(Nil))

  case cells(chunk) {
    [
      rank,
      team,
      points,
      played,
      won,
      lost,
      forfeits,
      _three_nil,
      _three_one,
      _three_two,
      _two_three,
      _one_three,
      _nil_three,
      sets_won,
      sets_lost,
      set_ratio,
      points_won,
      points_lost,
      point_ratio,
      ..
    ] -> {
      // FFVB numbers the rank "1.", "2." …
      use position <- result.try(int.parse(string.drop_end(rank, 1)))
      Ok(Row(
        rank: position,
        team:,
        ours: string.contains(chunk, "name=cnclub value=" <> ffvb.club_code),
        points: tally(points),
        played: tally(played),
        won: tally(won),
        lost: tally(lost),
        forfeits: tally(forfeits),
        sets_won: tally(sets_won),
        sets_lost: tally(sets_lost),
        set_ratio:,
        points_won: tally(points_won),
        points_lost: tally(points_lost),
        point_ratio:,
      ))
    }
    _ -> Error(Nil)
  }
}

/// FFVB leaves a cell empty rather than printing a zero.
fn tally(cell: String) -> Int {
  int.parse(cell) |> result.unwrap(0)
}

fn cells(chunk: String) -> List(String) {
  string.split(chunk, "<td")
  |> list.drop(1)
  |> list.map(cell_text)
}

fn cell_text(cell: String) -> String {
  case string.split_once(cell, ">") {
    Error(_) -> ""
    Ok(#(_attributes, rest)) ->
      case string.split_once(rest, "</td>") {
        Error(_) -> ""
        Ok(#(inner, _)) -> inner |> strip_tags |> string.trim
      }
  }
}

/// A poule title carries a gender icon, so the text is what survives the markup.
fn strip_tags(html: String) -> String {
  case string.split_once(html, "<") {
    Error(_) -> html
    Ok(#(text, rest)) ->
      case string.split_once(rest, ">") {
        Error(_) -> text
        Ok(#(_tag, after)) -> text <> strip_tags(after)
      }
  }
}

fn hidden(chunk: String, name: String) -> Result(String, Nil) {
  use #(_, rest) <- result.try(string.split_once(
    chunk,
    "name=" <> name <> " value='",
  ))
  use #(value, _) <- result.try(string.split_once(rest, "'"))
  Ok(value)
}

/// The FFVB page for the poule a table ranks.
pub fn table_url(table: Table) -> String {
  "https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier.php?saison="
  <> string.replace(ffvb.season, "/", "%2F")
  <> "&codent="
  <> table.entity
  <> "&poule="
  <> table.key
}

pub fn to_json(tables: List(Table), fetched_at: Int, stale: Bool) -> String {
  json.object([
    #("club", json.string(ffvb.club_name)),
    #("season", json.string(ffvb.season)),
    #("fetchedAt", json.int(fetched_at)),
    #("stale", json.bool(stale)),
    #("tables", json.array(tables, table_json)),
  ])
  |> json.to_string
}

fn table_json(table: Table) -> Json {
  json.object([
    #("key", json.string(table.key)),
    #("title", json.string(table.title)),
    #("level", json.string(table.level)),
    #("entity", json.string(table.entity)),
    #("ffvbUrl", json.string(table_url(table))),
    #("rows", json.array(table.rows, row_json)),
  ])
}

fn row_json(row: Row) -> Json {
  json.object([
    #("rank", json.int(row.rank)),
    #("team", json.string(row.team)),
    #("ours", json.bool(row.ours)),
    #("points", json.int(row.points)),
    #("played", json.int(row.played)),
    #("won", json.int(row.won)),
    #("lost", json.int(row.lost)),
    #("forfeits", json.int(row.forfeits)),
    #("setsWon", json.int(row.sets_won)),
    #("setsLost", json.int(row.sets_lost)),
    #("setRatio", json.string(row.set_ratio)),
    #("pointsWon", json.int(row.points_won)),
    #("pointsLost", json.int(row.points_lost)),
    #("pointRatio", json.string(row.point_ratio)),
  ])
}
