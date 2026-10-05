/* Ratio-only draft guidance. This does not model grip, speed, power or shifting. */
export function gearSpacing(controls, values = {}) {
  const gears = controls.filter(control => control.group === "Gearing" && Number.isInteger(control.gear)).sort((a, b) => a.gear - b.gear)
  return gears.slice(0, -1).map((control, index) => {
    const next = gears[index + 1]
    if (next.gear !== control.gear + 1) return null
    const from = values[control.id] ?? control.baseline, to = values[next.id] ?? next.baseline
    if (!Number.isFinite(from) || !Number.isFinite(to) || from <= 0 || to <= 0) return null
    return { from: control.gear, to: next.gear, percent: to / from * 100, rising: to >= from }
  }).filter(Boolean)
}
