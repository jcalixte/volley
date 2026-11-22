import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import volley
import volley/cp1252
import volley/ffvb

pub fn main() {
  gleeunit.main()
}

const sample =
  "Entit\u{00E9};Jo;Match;Date;Heure;EQA_no;EQA_nom;EQB_no;EQB_nom;Set;Score;Total;Salle;Arb1;Arb2;
ABCCS;01;2FC004;2026-09-27;13:30;0941410;VIE AU GRAND AIR DE ST MAUR;0929372;PLESSIS-ROBINSON VOLLEY-BALL;;;;BROSSOLETTE;;GARRAUT LORENZO;
ABCCS;02;2FC009;2026-10-04;14:00;0686625;AS SP ENTREMONT RIXHEIM;0941410;VIE AU GRAND AIR DE ST MAUR; 3/1;25-20,25-18,22-25,25-19;4;CITE DES SPORTS;LI09;;
LIIDF;14;PFAR069;2027-03-07;13:00;0757777;PUC VOLLEY-BALL 1;0941410;VIE AU GRAND AIR DE ST MAUR 2;;;;CHARPY;;;
"

pub fn parse_reads_a_home_fixture_test() {
  let assert [home, ..] = ffvb.parse(sample, ffvb.club_code)

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
  let assert [_, away, ..] = ffvb.parse(sample, ffvb.club_code)

  away.at_home |> should.be_false
  away.team |> should.equal("VIE AU GRAND AIR DE ST MAUR")
  away.opponent |> should.equal("AS SP ENTREMONT RIXHEIM")
}

pub fn parse_keeps_the_result_of_a_played_match_test() {
  let assert [_, played, ..] = ffvb.parse(sample, ffvb.club_code)

  played.sets |> should.equal("3-1")
  played.score |> should.equal("25-20,25-18,22-25,25-19")
}

pub fn parse_drops_the_header_row_test() {
  ffvb.parse(sample, ffvb.club_code) |> list.length |> should.equal(3)
}

pub fn parse_reads_a_four_letter_poule_test() {
  let assert [_, _, regional] = ffvb.parse(sample, ffvb.club_code)

  regional.poule |> should.equal("PFAR")
  regional.entity |> should.equal("LIIDF")
  regional.team |> should.equal("VIE AU GRAND AIR DE ST MAUR 2")
}

pub fn parse_ignores_rows_without_our_club_test() {
  let other =
    "header\nABCCS;01;2FC004;2026-09-27;13:30;0000001;A;0000002;B;;;;X;;;\n"

  ffvb.parse(other, ffvb.club_code) |> should.equal([])
}

pub fn parse_keeps_the_opponent_club_code_test() {
  let assert [home, away, ..] = ffvb.parse(sample, ffvb.club_code)

  home.opponent_code |> should.equal("0929372")
  away.opponent_code |> should.equal("0686625")
}

pub fn parse_reads_another_club_from_its_side_test() {
  let assert [match] = ffvb.parse(sample, "0686625")

  match.at_home |> should.be_true
  match.team |> should.equal("AS SP ENTREMONT RIXHEIM")
  match.opponent |> should.equal("VIE AU GRAND AIR DE ST MAUR")
  match.opponent_code |> should.equal(ffvb.club_code)
  match.sets |> should.equal("3-1")
}

pub fn club_label_keeps_our_own_name_test() {
  ffvb.parse(sample, ffvb.club_code)
  |> ffvb.club_label(ffvb.club_code, _)
  |> should.equal(ffvb.club_name)
}

pub fn club_label_picks_the_most_used_team_name_test() {
  let csv =
    "header
ABCCS;01;2MB001;2026-09-26;20:00;0885362;EPINAL GOLBEY VOLLEY-BALL (EGVB);0000001;A;;;;X;;;
ABCCS;02;2MB012;2026-10-04;15:00;0000002;B;0885362;EPINAL GOLBEY VOLLEY-BALL (EGVB);;;;X;;;
LILOR;01;RMA004;2026-10-03;20:00;0885362;EPINAL GOLBEY 3;0000003;C;;;;X;;;
"
  ffvb.parse(csv, "0885362")
  |> ffvb.club_label("0885362", _)
  |> should.equal("EPINAL GOLBEY VOLLEY-BALL (EGVB)")
}

pub fn club_label_falls_back_to_the_code_test() {
  ffvb.club_label("0885362", []) |> should.equal("0885362")
}

pub fn is_club_code_test() {
  ffvb.is_club_code("0885362") |> should.be_true
  ffvb.is_club_code("088536") |> should.be_false
  ffvb.is_club_code("08853620") |> should.be_false
  ffvb.is_club_code("088536a") |> should.be_false
  ffvb.is_club_code("") |> should.be_false
}

pub fn cp1252_decodes_accents_test() {
  // "FRÉDÉRICK" as FFVB sends it: É is a single 0xC9 byte, not UTF-8.
  <<"FR":utf8, 0xC9, "D":utf8, 0xC9, "RICK":utf8>>
  |> cp1252.decode
  |> should.equal("FRÉDÉRICK")
}

/// 0x92: a right single quote in windows-1252, a control character in latin-1.
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

pub fn competition_key_keeps_a_national_poule_whole_test() {
  let assert [national, ..] = ffvb.parse(sample, ffvb.club_code)
  ffvb.competition_key(national) |> should.equal("2FC")
}

pub fn competition_key_folds_the_two_regional_phases_test() {
  let assert [_, _, regional] = ffvb.parse(sample, ffvb.club_code)
  ffvb.competition_key(regional) |> should.equal("PFA")
}

pub fn competition_label_reproduces_the_ffvb_title_test() {
  let assert [national, ..] = ffvb.parse(sample, ffvb.club_code)
  ffvb.competition_label(national)
  |> should.equal("Nationale 2 Féminine · Poule C")
}

pub fn competition_label_keeps_the_code_for_a_regional_poule_test() {
  let assert [_, _, regional] = ffvb.parse(sample, ffvb.club_code)
  ffvb.competition_label(regional)
  |> should.equal("Île-de-France Féminine · PFA")
}

pub fn poule_url_points_at_the_official_calendar_test() {
  let assert [national, ..] = ffvb.parse(sample, ffvb.club_code)
  let url = ffvb.poule_url(national)
  url |> string.contains("poule=2FC") |> should.be_true
  url |> string.contains("codent=ABCCS") |> should.be_true
  url |> string.contains("saison=2026%2F2027") |> should.be_true
}

pub fn ttl_is_short_on_weekends_test() {
  // Saturday 2026-11-07 00:30 and Sunday 2026-11-08 23:30, Paris time.
  volley.ttl_seconds(1_794_007_800) |> should.equal(900)
  volley.ttl_seconds(1_794_177_000) |> should.equal(900)
}

pub fn ttl_is_long_on_weekdays_test() {
  // Friday 2026-11-06 23:30 and Monday 2026-11-09 00:30, Paris time.
  volley.ttl_seconds(1_794_004_200) |> should.equal(21_600)
  volley.ttl_seconds(1_794_180_600) |> should.equal(21_600)
}
