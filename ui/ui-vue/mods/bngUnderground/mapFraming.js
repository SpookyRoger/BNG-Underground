// Viewport arithmetic only. Does not choose roads, change navigation or drive a car.
export function framePoints(points, bounds) {
  if (!Array.isArray(points) || !Array.isArray(bounds) || bounds.length !== 4 || !bounds.every(Number.isFinite) || bounds[2] <= bounds[0] || bounds[3] <= bounds[1]) return null
  let xMin = Infinity, yMin = Infinity, xMax = -Infinity, yMax = -Infinity
  for (const point of points) {
    if (!Array.isArray(point) || !Number.isFinite(point[0]) || !Number.isFinite(point[1])) return null
    xMin = Math.min(xMin, point[0]); yMin = Math.min(yMin, point[1]); xMax = Math.max(xMax, point[0]); yMax = Math.max(yMax, point[1])
  }
  if (xMin === Infinity) return null
  const span = Math.max(bounds[2] - bounds[0], bounds[3] - bounds[1]), extent = Math.max(xMax - xMin, yMax - yMin, 1)
  const position = [xMin + (xMax - xMin) / 2, yMin + (yMax - yMin) / 2]
  if (![span, extent, ...position].every(Number.isFinite)) return null
  return { position, zoom: Math.min(4, Math.max(0.5, span * 0.75 / extent)) }
}
