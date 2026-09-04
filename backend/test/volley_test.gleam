import gleam/list
import gleeunit
import gleeunit/should
import volley/cp1252
import volley/ffvb

pub fn main() {
  gleeunit.main()
}

/// A verbatim slice of what the FFVB export returns, including the header row it
/// prefixes every file with.
const sample = "Entit\u{00E9};Jo;Match;Date;Heure;EQA_no;EQA_nom;EQB_no;EQB_nom;Set;Score;Total;Salle;Arb1;Arb2;
ABCCS;01;2FC004;2026-09-27;13:30;0941410;VIE AU GRAND AIR DE ST MAUR;0929372;PLESSIS-ROBINSON VOLLEY-BALL;;;;BROSSOLETTE;;GARRAUT LORENZO;
ABCCS;02;2FC009;2026-10-04;14:00;0686625;AS SP ENTREMONT RIXHEIM;0941410;VIE AU GRAND AIR DE ST MAUR;3-1;25-20,25-18,22-25,25-19;4;CITE DES SPORTS;LI09;;
LIIDF;14;PFAR069;2027-03-07;13:00;0757777;PUC VOLLEY-BALL 1;0941410;VIE AU GRAND AIR DE ST MAUR 2;;;;CHARPY;;;
"

pub fn parse_reads_a_home_fixture_test() {
  let assert [home, ..] = ffvb.parse(sample)

  home.code |> should.equal("2FC004")
  home.poule |> should.equal("2FC")
  home.date |> should.equal("2026-09-27")
  home.time |> should.equal("13:30")
  home.at_home |> should.be_true
  home.team |> should.equal("VIE AU GRAND AIR DE ST MAUR")
  home.opponent |> should.equal("PLESSIS-ROBINSON VOLLEY-BALL")
  home.venue |> should.equal("BROSSOLETTE")
  home.referees |> should.equal(["GARRAUT LORENZO"])
  home.score |> should.equal("")
}

pub fn parse_flips_the_sides_when_away_test() {
  let assert [_, away, ..] = ffvb.parse(sample)

  away.at_home |> should.be_false
  away.team |> should.equal("VIE AU GRAND AIR DE ST MAUR")
  away.opponent |> should.equal("AS SP ENTREMONT RIXHEIM")
}

/// The same file carries fixtures and results — a played match is one with a score.
pub fn parse_keeps_the_result_of_a_played_match_test() {
  let assert [_, played, ..] = ffvb.parse(sample)

  played.sets |> should.equal("3-1")
  played.score |> should.equal("25-20,25-18,22-25,25-19")
}

pub fn parse_drops_the_header_row_test() {
  ffvb.parse(sample) |> list.length |> should.equal(3)
}

/// A four-letter regional poule must not lose a letter to the fixed-width trim.
pub fn parse_reads_a_four_letter_poule_test() {
  let assert [_, _, regional] = ffvb.parse(sample)

  regional.poule |> should.equal("PFAR")
  regional.entity |> should.equal("LIIDF")
  regional.team |> should.equal("VIE AU GRAND AIR DE ST MAUR 2")
}

pub fn parse_ignores_rows_without_our_club_test() {
  let other =
    "header\nABCCS;01;2FC004;2026-09-27;13:30;0000001;A;0000002;B;;;;X;;;\n"

  ffvb.parse(other) |> should.equal([])
}

pub fn cp1252_decodes_accents_test() {
  // "FRÉDÉRICK" as FFVB sends it: É is a single 0xC9 byte, not UTF-8.
  <<"FR":utf8, 0xC9, "D":utf8, 0xC9, "RICK":utf8>>
  |> cp1252.decode
  |> should.equal("FRÉDÉRICK")
}

/// 0x92 is a control character in latin-1 but a right single quote in
/// windows-1252 — decoding as latin-1 would silently produce the wrong glyph.
pub fn cp1252_decodes_the_windows_only_range_test() {
  <<"L":utf8, 0x92, "AS":utf8>>
  |> cp1252.decode
  |> should.equal("L\u{2019}AS")
}

pub fn cp1252_leaves_ascii_alone_test() {
  <<"PUC VOLLEY-BALL 1":utf8>>
  |> cp1252.decode
  |> should.equal("PUC VOLLEY-BALL 1")
}
