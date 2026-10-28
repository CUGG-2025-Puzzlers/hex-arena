extends RefCounted
class_name PlaytestVisionMask

## Exact hex polygons come from the grid's wall cells/collision geometry.
static func has_line_of_sight(origin: Vector2, target: Vector2, walls: Array[PackedVector2Array]) -> bool:
	for polygon in walls:
		if Geometry2D.is_point_in_polygon(origin, polygon) or Geometry2D.is_point_in_polygon(target, polygon):
			return false
		for i in range(polygon.size()):
			if Geometry2D.segment_intersects_segment(origin, target, polygon[i], polygon[(i + 1) % polygon.size()]) != null:
				return false
	return true

static func clip_segment(origin: Vector2, target: Vector2, walls: Array[PackedVector2Array]) -> Vector2:
	var closest := target
	for polygon in walls:
		if Geometry2D.is_point_in_polygon(origin, polygon):
			return origin
		for i in range(polygon.size()):
			var hit: Variant = Geometry2D.segment_intersects_segment(origin, target, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit is Vector2 and origin.distance_squared_to(hit) < origin.distance_squared_to(closest):
				closest = hit
	return closest
