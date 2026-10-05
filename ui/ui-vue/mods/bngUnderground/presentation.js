export const money = value => "$" + Math.floor(value || 0).toLocaleString("en-US")
export const distance = value => value == null ? "" : value < 1000 ? value + " m" : (value / 1000).toFixed(1) + " km"
export const array = value => Array.isArray(value) ? value : []
export const carImage = car => "/vehicles/" + car.model + "/" + car.configs.stock + ".jpg"
export const paintColor = paint => "rgb(" + paint.rgba.slice(0, 3).map(x => Math.round(x * 255)).join(",") + ")"
export const controlDisplayValue = (control, value) => {
  const raw = value ?? control.baseline, mapping = control.display
  return mapping ? mapping.min + (raw - mapping.rawMin) / (mapping.rawMax - mapping.rawMin) * (mapping.max - mapping.min) : raw * control.scale
}
export const controlText = (control, value) => Number(controlDisplayValue(control, value).toFixed(control.display || control.scale === 100 ? 1 : 2)).toLocaleString("en-US")
export const controlRange = control => controlText(control, control.display?.rawMin ?? control.min) + "–" + controlText(control, control.display?.rawMax ?? control.max)
export const disciplines = ["All", "Circuit", "Sprint", "Time attack", "Drift", "Drag", "Rival"]
export const raceTime = seconds => {
  if (!Number.isFinite(seconds) || seconds < 0) return "—"
  const precision = Number.isInteger(seconds) ? 0 : 2, rounded = Math.round(seconds * 100) / 100
  const minutes = Math.floor(rounded / 60), remainder = rounded - minutes * 60
  return minutes + ":" + remainder.toFixed(precision).padStart(precision ? 5 : 2, "0")
}
export const courseLabel = event => event.course
  ? event.course.layout + (event.course.layout === "Circuit" ? " · " + event.course.laps + (event.course.laps === 1 ? " lap" : " laps") : "")
  : event.kind === "Drag" ? "Standing start · win and beat the clock" : event.kind === "Drift" ? "Score run" : event.kind
export const basePayoutLabel = event => event.payout
  ? money(event.payout.min) + (event.payout.max > event.payout.min ? "–" + money(event.payout.max) : "")
  : "—"
export const payoutLabel = event => event.payout?.sponsor
  ? money(event.payout.sponsor.totalMin) + (event.payout.sponsor.totalMax > event.payout.sponsor.totalMin ? "–" + money(event.payout.sponsor.totalMax) : "")
  : basePayoutLabel(event)
export const sponsorLabel = event => event.payout?.sponsor
  ? event.payout.sponsor.name + " · +" + Math.round(event.payout.sponsor.rate * 100) + "% · " + (event.payout.sponsor.completion ? "includes " + money(event.payout.sponsor.completion) + " contract completion" : event.payout.sponsor.newClear ? "new contract clear" : "already delivered · race bonus only")
  : ""
export const raceTargets = event => {
  const targets = event.overrides || {}
  if (event.boss) return [{ medal: "Gold", target: "1st place · rival clear" }]
  if (event.missionType === "aiRace") return [{ medal: "Bronze", target: "Podium" }, { medal: "Silver", target: "Top two" }, { medal: "Gold", target: "1st place" }]
  return ["Bronze", "Silver", "Gold"].map(medal => {
    const lower = medal.toLowerCase()
    const value = event.kind === "Drag" ? targets["time" + medal] : event.kind === "Drift" ? targets[lower + "Points"] : targets[lower + "Time"]
    return { medal, target: event.kind === "Drift" ? Number(value || 0).toLocaleString("en-US") + " points" : raceTime(value) }
  })
}
