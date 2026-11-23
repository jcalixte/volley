//// The CSV export names the hall but gives no address, and a hall name plus a
//// club name ("COUCHOT", "ACBB 2") is too vague for Google Maps. FFVB's match
//// sheet PDF prints the hall's full postal address, so read it from there.

import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import gleam/uri
import volley/cp1252
import volley/ffvb.{type Match}

const host = "www.ffvbbeach.org"

const sheet_path = "/ffvbapp/adressier/fiche_match_ffvb.php"

/// Matches still to play between two ISO dates, inclusive, at a named hall:
/// the ones whose address is worth looking up ahead of a click.
pub fn due(matches: List(Match), from: String, until: String) -> List(Match) {
  list.filter(matches, fn(match) {
    match.sets == ""
    && match.venue != ""
    && string.compare(match.date, from) != order.Lt
    && string.compare(match.date, until) != order.Gt
  })
}

pub fn fetch_address(entity: String, code: String) -> Result(String, String) {
  let form =
    uri.query_to_string([
      #("wss_saison", ffvb.season),
      #("codmatch", code),
      #("codent", entity),
    ])

  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> request.set_host(host)
    |> request.set_path(sheet_path)
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> request.set_body(<<form:utf8>>)

  // Someone is waiting on a click, and a vaguer address beats no map at all.
  let config = httpc.configure() |> httpc.timeout(8000)

  use response <- result.try(
    httpc.dispatch_bits(config, req)
    |> result.replace_error("could not reach " <> host),
  )
  case response.status {
    200 ->
      response.body
      |> pdf_text
      |> cp1252.decode
      |> address
      |> result.replace_error("no hall address on the sheet of " <> code)
    status -> Error("match sheet returned HTTP " <> string.inspect(status))
  }
}

@external(erlang, "volley_ffi", "pdf_text")
fn pdf_text(pdf: BitArray) -> BitArray

/// The sheet prints a "Salle" heading, then the hall's name, street and
/// "postcode town" line. Reads up to the postcode line, which closes the block.
pub fn address(content: String) -> Result(String, Nil) {
  let texts = content |> string.split("\n") |> list.filter_map(shown_text)
  use after <- result.try(
    texts |> list.drop_while(fn(text) { text != "Salle" }) |> list.rest,
  )
  let lines =
    after
    |> list.take(5)
    |> list.map(string.trim)
    |> list.filter(fn(line) { line != "" })
  let #(before, from_town) =
    list.split_while(lines, fn(line) { !is_town(line) })
  use town <- result.try(list.first(from_town))
  case before {
    [] -> Error(Nil)
    _ -> Ok(string.join(list.append(before, [town]), ", "))
  }
}

/// One drawn string: `q 0 g BT 262.25 627.93 Td (COUCHOT) Tj ET Q`.
fn shown_text(line: String) -> Result(String, Nil) {
  use #(_, rest) <- result.try(string.split_once(line, " Td ("))
  use #(text, _) <- result.try(string.split_once(rest, ") Tj"))
  Ok(
    text
    |> string.replace("\\(", "(")
    |> string.replace("\\)", ")")
    |> string.replace("\\\\", "\\"),
  )
}

fn is_town(line: String) -> Bool {
  case string.split_once(line, " ") {
    Ok(#(postcode, _)) ->
      string.length(postcode) == 5
      && string.to_graphemes(postcode) |> list.all(is_digit)
    Error(_) -> False
  }
}

fn is_digit(char: String) -> Bool {
  string.contains("0123456789", char)
}

pub fn maps_url(destination: String, directions: Bool) -> String {
  case directions {
    True ->
      "https://www.google.com/maps/dir/?"
      <> uri.query_to_string([#("api", "1"), #("destination", destination)])
    False ->
      "https://www.google.com/maps/search/?"
      <> uri.query_to_string([#("api", "1"), #("query", destination)])
  }
}
