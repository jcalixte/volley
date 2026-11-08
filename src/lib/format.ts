const MONTH = new Intl.DateTimeFormat("fr-FR", { month: "long", year: "numeric" })
const MONTH_SHORT = new Intl.DateTimeFormat("fr-FR", { month: "short" })
const WEEKDAY = new Intl.DateTimeFormat("fr-FR", { weekday: "short" })
const FULL = new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" })
const DAY_MONTH = new Intl.DateTimeFormat("fr-FR", { day: "numeric", month: "short" })

export const monthLabel = (date: Date) => MONTH.format(date)
export const monthShortLabel = (date: Date) => MONTH_SHORT.format(date).replace(".", "")
export const weekdayLabel = (date: Date) => WEEKDAY.format(date).replace(".", "")
export const fullDate = (date: Date) => FULL.format(date)
export const shortDate = (date: Date) => DAY_MONTH.format(date)

export function relativeTime(seconds: number): string {
  const minutes = Math.max(0, Math.round((Date.now() / 1000 - seconds) / 60))
  if (minutes < 1) return "à l'instant"
  if (minutes < 60) return `il y a ${minutes} min`
  const hours = Math.round(minutes / 60)
  return hours < 24 ? `il y a ${hours} h` : `il y a ${Math.round(hours / 24)} j`
}

const DAY_MS = 86_400_000

// Calendar days, not 24-hour blocks: a Saturday match seen on Friday night is
// "Demain" whatever the hour. Rounding absorbs the 23- and 25-hour DST days.
export function countdown(kickoff: Date, now: Date): string {
  const midnight = (date: Date) =>
    new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
  const days = Math.round((midnight(kickoff) - midnight(now)) / DAY_MS)
  if (days <= 0) return "Aujourd'hui"
  if (days === 1) return "Demain"
  return `Dans ${days} jours`
}
