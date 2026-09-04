//// FFVB serves its exports as windows-1252, not UTF-8, so team names like
//// "VANDENBEMDEN FRÉDÉRICK" arrive as raw bytes that no UTF-8 decoder accepts.

import gleam/list
import gleam/string

/// Decode a windows-1252 byte string into a Gleam String.
pub fn decode(bits: BitArray) -> String {
  do_decode(bits, [])
}

fn do_decode(bits: BitArray, acc: List(UtfCodepoint)) -> String {
  case bits {
    <<byte:int-size(8), rest:bits>> ->
      case string.utf_codepoint(codepoint(byte)) {
        Ok(char) -> do_decode(rest, [char, ..acc])
        Error(_) -> do_decode(rest, acc)
      }
    _ -> acc |> list.reverse |> string.from_utf_codepoints
  }
}

/// windows-1252 agrees with latin-1 everywhere except 0x80-0x9F, where latin-1
/// has control characters and windows-1252 puts typography.
fn codepoint(byte: Int) -> Int {
  case byte {
    0x80 -> 0x20AC
    0x82 -> 0x201A
    0x83 -> 0x0192
    0x84 -> 0x201E
    0x85 -> 0x2026
    0x86 -> 0x2020
    0x87 -> 0x2021
    0x88 -> 0x02C6
    0x89 -> 0x2030
    0x8A -> 0x0160
    0x8B -> 0x2039
    0x8C -> 0x0152
    0x8E -> 0x017D
    0x91 -> 0x2018
    0x92 -> 0x2019
    0x93 -> 0x201C
    0x94 -> 0x201D
    0x95 -> 0x2022
    0x96 -> 0x2013
    0x97 -> 0x2014
    0x98 -> 0x02DC
    0x99 -> 0x2122
    0x9A -> 0x0161
    0x9B -> 0x203A
    0x9C -> 0x0153
    0x9E -> 0x017E
    0x9F -> 0x0178
    0x81 | 0x8D | 0x8F | 0x90 | 0x9D -> 0xFFFD
    other -> other
  }
}
