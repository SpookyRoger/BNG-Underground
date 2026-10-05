import { lua, useBridge } from "@/bridge"
import { awaitTransaction } from "./transactionResult.js"

// lua is a fixed table of native function signatures, not a dynamic proxy.
// Custom extension functions use the public engine API and its Lua serializer.
// Only the fixed method names below reach this helper; starter IDs are arguments.
function callCampaign(method, args = []) {
  const { api } = useBridge()
  const parameters = args.map(value => api.serializeToLua(value)).join(",")
  return new Promise(resolve => {
    api.engineLua(`extensions.bngUnderground.${method}(${parameters})`, resolve)
  })
}

async function ensureLoaded() {
  if (await lua.extensions.isExtensionLoaded("bngUnderground")) return
  await lua.extensions.load("bngUnderground")
  if (!await lua.extensions.isExtensionLoaded("bngUnderground")) {
    throw new Error("The BNG Underground campaign extension could not load. Check beamng.log for details.")
  }
}

export async function getLaunchData() {
  await ensureLoaded()
  return callCampaign("getLaunchData")
}

export async function launchFromMenu(starter) {
  await ensureLoaded()
  return callCampaign("launchFromMenu", [starter])
}

export async function isActive() {
  await ensureLoaded()
  return callCampaign("isActive")
}

export async function showBoard(page = "city") {
  await ensureLoaded()
  return callCampaign("showBoard", [page])
}
export async function getMapData() {
  await ensureLoaded()
  return callCampaign("getMapData")
}
export async function getCourseData(eventId) {
  await ensureLoaded()
  return callCampaign("getCourseData", [eventId])
}

export async function requestState() {
  await ensureLoaded()
  return callCampaign("requestState")
}

export async function command(action, argument = null) {
  await ensureLoaded()
  const result = await callCampaign("command", [action, argument])
  return awaitTransaction(result, ticket => callCampaign("getTransactionResult", [ticket]), milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds)))
}
