import gleam/list
import gleeunit/should
import volley/standings

/// A trimmed but faithful slice of planning_club_class.php: one national table
/// and one departmental one. The hidden inputs are kept verbatim — they are what
/// identifies the entity and our own lines — while the printer and calendar
/// forms that follow them on the real page are dropped.
const sample = "<TABLE>
<tr><td bgcolor='#33CCCC' class='lienblanc' align='center'>NAT</td><td class='titrepoule' align='left' colspan='7'><IMG SRC='../images/masculin.png' WIDTH=18 HEIGHT=18 align='absmiddle'>2MB - NATIONALE 2 MASCULINE - POULE B</td></tr>
<tr bgcolor='#EEEEF8'><td class='liengris_pt' align='right'>1.</td><td class='lienquestion_pt' align='left'>EPINAL GOLBEY VOLLEY-BALL (EGVB)</td><td class='lienblanc_pt' align='center'>9</td><td class='liengris_pt' align='right'>3</td><td class='liengris_pt' align='right'>3</td><td></td><td></td><td class='liengris_pt' align='right'>2</td><td class='liengris_pt' align='right'>1</td><td></td><td></td><td></td><td></td><td class='liengris_pt' align='right'>9</td><td class='liengris_pt' align='right'>1</td><td class='liengris_pt' align='right'>9.000</td><td class='liengris_pt' align='right'>254</td><td class='liengris_pt' align='right'>206</td><td class='liengris_pt' align='right'>1.233</td><form name=divers method=get action='vbspo_calendrier.php'><td align='left' class='lienquestion'><input type=hidden name=saison value='2026/2027'><input type=hidden name=codent value='ABCCS'><input type=hidden name=poule value='2MB'><input type=image src='ico_spo_loupe.png'></td></form><form name=divers method=get action='planning_club.php'><td align='center'><input type=hidden name=cnclub value=0885362></td></form></tr>
<tr bgcolor='#EEEEF8'><td class='liengris_pt' align='right'>5.</td><td class='liengris_pt' align='left'>VIE AU GRAND AIR DE ST MAUR</td><td class='lienblanc_pt' align='center'>4</td><td class='liengris_pt' align='right'>3</td><td class='liengris_pt' align='right'>2</td><td class='liengris_pt' align='right'>1</td><td></td><td></td><td class='liengris_pt' align='right'>2</td><td></td><td class='liengris_pt' align='right'>1</td><td></td><td></td><td class='liengris_pt' align='right'>7</td><td class='liengris_pt' align='right'>7</td><td class='liengris_pt' align='right'>1.000</td><td class='liengris_pt' align='right'>311</td><td class='liengris_pt' align='right'>306</td><td class='liengris_pt' align='right'>1.016</td><form name=divers method=get action='vbspo_calendrier.php'><td align='left' class='lienquestion'><input type=hidden name=saison value='2026/2027'><input type=hidden name=codent value='ABCCS'><input type=hidden name=poule value='2MB'><input type=image src='ico_spo_loupe.png'></td></form><form name=divers method=get action='planning_club.php'><td align='center'><input type=hidden name=cnclub value=0941410></td></form></tr>
<tr><td bgcolor='#FF9900' class='lienblanc' align='center'>DEP</td><td class='titrepoule' align='left' colspan='7'><IMG SRC='../images/masculin.png' WIDTH=18 HEIGHT=18 align='absmiddle'>ARM - ACCESSION REGIONALE - MASCULINS 94</td></tr>
<tr bgcolor='#EEEEF8'><td class='liengris_pt' align='right'>1.</td><td class='lienquestion_pt' align='left'>VGA ST MAUR 3</td><td class='lienblanc_pt' align='center'>9</td><td class='liengris_pt' align='right'>3</td><td class='liengris_pt' align='right'>3</td><td></td><td></td><td class='liengris_pt' align='right'>2</td><td class='liengris_pt' align='right'>1</td><td></td><td></td><td></td><td></td><td class='liengris_pt' align='right'>9</td><td></td><td class='liengris_pt' align='right'>MAX</td><td class='liengris_pt' align='right'>251</td><td class='liengris_pt' align='right'>200</td><td class='liengris_pt' align='right'>1.255</td><form name=divers method=get action='vbspo_calendrier.php'><td align='left' class='lienquestion'><input type=hidden name=saison value='2026/2027'><input type=hidden name=codent value='PTIDF94'><input type=hidden name=poule value='ARM'><input type=image src='ico_spo_loupe.png'></td></form><form name=divers method=get action='planning_club.php'><td align='center'><input type=hidden name=cnclub value=0941410></td></form></tr>
</TABLE>
"

pub fn parse_finds_every_table_test() {
  standings.parse(sample)
  |> list.map(fn(table) { table.key })
  |> should.equal(["2MB", "ARM"])
}

/// The code belongs to the app's own competition key, so the title it carries is
/// only the name FFVB prints after it.
pub fn parse_splits_the_code_off_the_title_test() {
  let assert [national, ..] = standings.parse(sample)

  national.title |> should.equal("NATIONALE 2 MASCULINE - POULE B")
  national.level |> should.equal("NAT")
  national.entity |> should.equal("ABCCS")
}

pub fn parse_reads_a_whole_line_test() {
  let assert [national, ..] = standings.parse(sample)
  let assert [leader, ..] = national.rows

  leader.rank |> should.equal(1)
  leader.team |> should.equal("EPINAL GOLBEY VOLLEY-BALL (EGVB)")
  leader.points |> should.equal(9)
  leader.played |> should.equal(3)
  leader.won |> should.equal(3)
  leader.sets_won |> should.equal(9)
  leader.sets_lost |> should.equal(1)
  leader.set_ratio |> should.equal("9.000")
  leader.points_won |> should.equal(254)
  leader.points_lost |> should.equal(206)
  leader.point_ratio |> should.equal("1.233")
}

/// An empty cell is FFVB's way of printing a zero.
pub fn parse_reads_an_empty_cell_as_zero_test() {
  let assert [national, ..] = standings.parse(sample)
  let assert [leader, ..] = national.rows

  leader.lost |> should.equal(0)
  leader.forfeits |> should.equal(0)
}

/// Our own lines are found by the club code FFVB stamps on them — the name alone
/// would miss "VGA ST MAUR 3", which is the same club under another spelling.
pub fn parse_marks_our_own_lines_test() {
  let assert [national, departmental] = standings.parse(sample)

  national.rows
  |> list.filter(fn(row) { row.ours })
  |> list.length
  |> should.equal(1)
  let assert [ours] = list.filter(national.rows, fn(row) { row.ours })
  ours.rank |> should.equal(5)

  let assert [theirs] = departmental.rows
  theirs.ours |> should.be_true
  theirs.team |> should.equal("VGA ST MAUR 3")
}

/// No set conceded leaves FFVB with no ratio to print, so it prints "MAX".
pub fn parse_keeps_an_unbeaten_ratio_test() {
  let assert [_, departmental] = standings.parse(sample)
  let assert [leader] = departmental.rows

  leader.set_ratio |> should.equal("MAX")
  leader.sets_lost |> should.equal(0)
}

pub fn table_url_points_at_the_poule_test() {
  let assert [_, departmental] = standings.parse(sample)

  standings.table_url(departmental)
  |> should.equal(
    "https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier.php?saison=2026%2F2027&codent=PTIDF94&poule=ARM",
  )
}
