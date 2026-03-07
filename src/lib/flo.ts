export type FloSelector = string

export interface NormalizedSelector {
  raw: FloSelector
  value: string
}

export const normalizeSelector = (selector: FloSelector): NormalizedSelector => ({
  raw: selector,
  value: selector.trim(),
})
