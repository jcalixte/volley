const MONTH = new Intl.DateTimeFormat("fr-FR", { month: "long", year: "numeric" })
const WEEKDAY = new Intl.DateTimeFormat("fr-FR", { weekday: "short" })
const FULL = new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" })

export const monthLabel = (date: Date) => MONTH.format(date)
export const weekdayLabel = (date: Date) => WEEKDAY.format(date).replace(".", "")
export const fullDate = (date: Date) => FULL.format(date)

export function relativeTime(seconds: number): string {
  const minutes = Math.max(0, Math.round((Date.now() / 1000 - seconds) / 60))
  if (minutes < 1) return "à l'instant"
  if (minutes < 60) return `il y a ${minutes} min`
  const hours = Math.round(minutes / 60)
  return hours < 24 ? `il y a ${hours} h` : `il y a ${Math.round(hours / 24)} j`
}
