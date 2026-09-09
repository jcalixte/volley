// A player away for part of the season. The window is stored as the same
// `YYYY-MM-DD` string FFVB publishes, so the comparison is lexicographic and
// never crosses a timezone.
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
