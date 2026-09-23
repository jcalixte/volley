import type { Match } from "./matches"
import { weekdayLabel } from "./format"

export interface CalendarDay {
  /** `YYYY-MM-DD`, the same key FFVB publishes on a match. */
  key: string
  date: Date
  weekend: boolean
  /** A day borrowed from the previous or next month to fill the row. */
  outside: boolean
  today: boolean
  matches: Match[]
}

export function dateKey(date: Date): string {
  const month = `${date.getMonth() + 1}`.padStart(2, "0")
  const day = `${date.getDate()}`.padStart(2, "0")
  return `${date.getFullYear()}-${month}-${day}`
}

// France reads a week Monday first, so Sunday closes the row instead of
// opening it, and the weekend is the last two columns.
function mondayIndex(date: Date): number {
  return (date.getDay() + 6) % 7
}

export function addMonths(anchor: Date, delta: number): Date {
  return new Date(anchor.getFullYear(), anchor.getMonth() + delta, 1)
}

export function startOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), 1)
}

/** Full weeks covering the anchor's month, every day carrying its matches. */
export function monthGrid(anchor: Date, matches: Match[], today = new Date()): CalendarDay[][] {
  const byDate = new Map<string, Match[]>()
  for (const match of matches) {
    const bucket = byDate.get(match.date)
    if (bucket) bucket.push(match)
    else byDate.set(match.date, [match])
  }

  const first = startOfMonth(anchor)
  const last = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0)
  const cursor = new Date(first)
  cursor.setDate(1 - mondayIndex(first))

  const todayKey = dateKey(today)
  const weeks: CalendarDay[][] = []
  while (cursor <= last) {
    const week: CalendarDay[] = []
    for (let column = 0; column < 7; column += 1) {
      const date = new Date(cursor)
      const key = dateKey(date)
      week.push({
        key,
        date,
        weekend: column >= 5,
        outside: date.getMonth() !== first.getMonth(),
        today: key === todayKey,
        matches: byDate.get(key) ?? [],
      })
      cursor.setDate(cursor.getDate() + 1)
    }
    weeks.push(week)
  }
  return weeks
}

// 2024-01-01 was a Monday, so a week read from it lands the labels in the same
// order as the grid's columns.
export const weekdayHeaders = Array.from({ length: 7 }, (_, index) =>
  weekdayLabel(new Date(2024, 0, 1 + index)),
)
