/** FFVB's code for Vie au Grand Air de Saint-Maur, the club this page is for. */
export const HOME_CLUB = "0941410"

const CLUB_PARAM = "club"

/** The club the page shows: `?club=<FFVB code>`, or ours without it. */
export function viewedClub(): string {
  const code = new URLSearchParams(location.search).get(CLUB_PARAM) ?? ""
  return /^\d{7}$/.test(code) ? code : HOME_CLUB
}

export function isHomeClub(): boolean {
  return viewedClub() === HOME_CLUB
}

/** A bye has no club code, so it gets no link. */
export function clubUrl(code: string): string | undefined {
  if (!/^\d{7}$/.test(code)) return undefined
  return code === HOME_CLUB ? "/" : `/?${CLUB_PARAM}=${code}`
}

/** The query the API needs for the viewed club; empty for ours. */
export function clubQuery(): string {
  return isHomeClub() ? "" : `?${CLUB_PARAM}=${viewedClub()}`
}
