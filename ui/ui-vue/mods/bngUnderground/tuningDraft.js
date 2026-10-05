// Native-value editing only; no vehicle physics or campaign persistence here.
export const closeValue = (a, b) => Number.isFinite(a) && Number.isFinite(b) && Math.abs(a - b) <= 0.0000001
export function savedValues(controls, overrides = {}) {
  return Object.fromEntries(controls.map(control => [control.id, overrides[control.id] ?? control.baseline]))
}
export function adjustValue(control, value, direction) {
  const reversed = control.display && control.display.rawMax < control.display.rawMin
  const next = (value ?? control.baseline) + direction * (reversed ? -1 : 1) * control.step
  return Number(Math.min(control.max, Math.max(control.min, next)).toFixed(8))
}
