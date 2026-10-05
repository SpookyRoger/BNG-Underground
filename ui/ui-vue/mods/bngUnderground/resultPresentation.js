import { raceTime } from "./presentation.js"
const positive = value => Number.isFinite(value) && value > 0
export const resultOutcome = entry => !entry?.won ? "Target missed" :
  (entry.medal ? entry.medal[0].toUpperCase() + entry.medal.slice(1) : "Clear") + " · " + (entry.first ? "First clear" : "Replay")
export const resultMeasurement = entry => {
  const data = entry?.metrics || {}
  if (entry?.missionType === "drift") return Number.isFinite(data.score) && data.score >= 0 ? Math.round(data.score).toLocaleString("en-US") + " points" : "No score reported"
  const values = []
  if ((entry?.missionType === "aiRace" || entry?.missionType === "dragStripRace") && positive(data.place) && Number.isInteger(data.place)) values.push("Place " + data.place)
  if (positive(data.time)) values.push(raceTime(data.time))
  return values.join(" · ") || "No measurement reported"
}
export const nativeResultDate = seconds => {
  if (!positive(seconds) || !Number.isInteger(seconds)) return ""
  const date = new Date(seconds * 1000)
  return Number.isFinite(date.getTime()) ? date.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }) : ""
}
