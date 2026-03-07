export const shellQuote = (value: string): string => `'${value.replaceAll(`'`, `'\\''`)}'`

export const slugify = (value: string): string =>
  value
    .normalize(`NFKD`)
    .replaceAll(/\p{Diacritic}/gu, ``)
    .toLowerCase()
    .replaceAll(/[^a-z0-9]+/g, `-`)
    .replaceAll(/^-+|-+$/g, ``)
    .slice(0, 48) || `work`

export const sanitizeIdentifier = (value: string): string =>
  value.replaceAll(/[^a-zA-Z0-9._-]+/g, `-`).replaceAll(/^-+|-+$/g, ``) || `flo`

export const normalizeMatchKey = (value: string): string => value.trim().toLowerCase()

export const looksLikeAbsolutePath = (value: string): boolean =>
  value.startsWith(`/`) || value.startsWith(`~/`)

export const expandHome = (value: string, homeDirectory: string): string =>
  value.startsWith(`~/`) ? `${homeDirectory}/${value.slice(2)}` : value
