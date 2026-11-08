// `from`/`to` are `YYYY-MM-DD` strings, compared lexicographically so no
// timezone is involved.
export interface Absence {
  flag: string
  reason: string
  from: string
  to: string
}

export const ABSENCES: Absence[] = [
  { flag: "🇯🇵", reason: "Passeur au Japon", from: "2026-11-17", to: "2027-02-15" },
]

export function absenceOn(date: string, absences: Absence[] = ABSENCES): Absence | undefined {
  return absences.find((absence) => date >= absence.from && date <= absence.to)
}
