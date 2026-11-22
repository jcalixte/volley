import gleeunit/should
import volley/salle

// Trimmed from the content stream of FFVB's sheet for match 2MB042.
const sheet =
  "BT /F2 8.00 Tf ET
q 0 g BT 288.75 649.57 Td (Salle) Tj ET Q
0.941 g
85.04 643.46 m 85.04 530.08 l S q 0 g BT 290.55 584.37 Td () Tj ET Q
BT /F1 14.00 Tf ET
q 0 g BT 262.25 627.93 Td (COUCHOT) Tj ET Q
q 0 g BT 252.64 614.95 Td (2 RUE COUCHOT  ) Tj ET Q
q 0 g BT 204.04 600.18 Td (92100 BOULOGNE BILLANCOURT) Tj ET Q
q 0 g BT 266.44 544.69 Td (Sol : Parquet) Tj ET Q
q 0 g BT 281.63 516.34 Td (Salle principale :) Tj ET Q
q 0 g BT 262.25 500.00 Td (BROSSOLETTE) Tj ET Q
q 0 g BT 262.25 490.00 Td (51 AV PIERRE BROSSOLETTE) Tj ET Q
q 0 g BT 262.25 480.00 Td (94100 SAINT MAUR) Tj ET Q
"

pub fn address_reads_the_match_hall_block_test() {
  salle.address(sheet)
  |> should.equal(Ok("COUCHOT, 2 RUE COUCHOT, 92100 BOULOGNE BILLANCOURT"))
}

pub fn address_unescapes_parentheses_test() {
  "q 0 g BT 1 1 Td (Salle) Tj ET Q
q 0 g BT 1 1 Td (CHATAIGNIERS \\(ANCIENNE SALLE\\)) Tj ET Q
q 0 g BT 1 1 Td (95100 ARGENTEUIL) Tj ET Q
"
  |> salle.address
  |> should.equal(Ok("CHATAIGNIERS (ANCIENNE SALLE), 95100 ARGENTEUIL"))
}

pub fn address_needs_a_postcode_line_test() {
  "q 0 g BT 1 1 Td (Salle) Tj ET Q
q 0 g BT 1 1 Td () Tj ET Q
q 0 g BT 1 1 Td (Sol : ) Tj ET Q
"
  |> salle.address
  |> should.equal(Error(Nil))
}

pub fn maps_url_routes_to_the_address_test() {
  salle.maps_url("COUCHOT, 92100 BOULOGNE", True)
  |> should.equal(
    "https://www.google.com/maps/dir/?api=1&destination=COUCHOT%2C%2092100%20BOULOGNE",
  )
}
