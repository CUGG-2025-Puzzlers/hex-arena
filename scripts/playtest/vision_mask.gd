extends RefCounted
class_name PlaytestVisionMask

## Segment/AABB test shared by entity visibility and the fog cell mask.
## Walls use these same rectangles for physics, placement rejection and rendering.
static func has_line_of_sight(origin: Vector2, target: Vector2, walls: Array[Rect2]) -> bool:
	for wall in walls:
		if segment_hits_rect(origin, target, wall):
			return false
	return true

static func segment_hits_rect(origin: Vector2, target: Vector2, rect: Rect2) -> bool:
	var direction := target - origin
	var near_t := 0.0
	var far_t := 1.0
	for axis in range(2):
		if absf(direction[axis]) < 0.00001:
			if origin[axis] < rect.position[axis] or origin[axis] > rect.end[axis]:
				return false
			continue
		var first := (rect.position[axis] - origin[axis]) / direction[axis]
		var second := (rect.end[axis] - origin[axis]) / direction[axis]
		near_t = maxf(near_t, minf(first, second))
		far_t = minf(far_t, maxf(first, second))
		if near_t > far_t:
			return false
	return true


static func clip_segment(origin: Vector2, target: Vector2, walls: Array[Rect2]) -> Vector2:
	var closest := target
	for rect in walls:
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in range(4):
			var hit: Variant = Geometry2D.segment_intersects_segment(origin, target, corners[i], corners[(i + 1) % 4])
			if hit is Vector2 and origin.distance_squared_to(hit) < origin.distance_squared_to(closest):
				closest = hit
	return closest
