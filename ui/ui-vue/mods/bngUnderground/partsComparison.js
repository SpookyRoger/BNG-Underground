// Read-only comparison of projected native adjustments. No purchases or performance estimates.
const sameSetup = (before, after) => ["min", "max", "baseline", "step", "scale", "unit"].every(key => before[key] === after[key])
  && ["rawMin", "rawMax", "min", "max", "step"].every(key => before.display?.[key] === after.display?.[key])
export function compareAdjustments(current, proposed) {
  const before = new Map(current.map(control => [control.id, control]))
  const after = new Map(proposed.map(control => [control.id, control]))
  const ids = [...before.keys(), ...[...after.keys()].filter(id => !before.has(id))]
  const rows = ids.map(id => {
    const left = before.get(id), right = after.get(id)
    return { id, before: left, after: right, kind: !left ? "added" : !right ? "removed" : sameSetup(left, right) ? "retained" : "changed" }
  })
  return { rows, currentCount: before.size, proposedCount: after.size,
    added: rows.filter(row => row.kind === "added"), removed: rows.filter(row => row.kind === "removed"), changed: rows.filter(row => row.kind === "changed") }
}
