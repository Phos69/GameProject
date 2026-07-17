class_name GeometryUtils
extends RefCounted

# Helper geometrici puri condivisi da generazione mondo, pass di placement e
# visual _draw. Unica fonte per i corpi prima duplicati (gruppo 4.1 di
# docs/repo_health_report_2026-07-17.md).

static func clip_rect(rect: Rect2i, zone_size: Vector2i) -> Rect2i:
	var x := clampi(rect.position.x, 0, zone_size.x)
	var y := clampi(rect.position.y, 0, zone_size.y)
	var end_x := clampi(rect.end.x, 0, zone_size.x)
	var end_y := clampi(rect.end.y, 0, zone_size.y)
	return Rect2i(
		Vector2i(x, y),
		Vector2i(maxi(end_x - x, 0), maxi(end_y - y, 0))
	)

static func inflate_rect(rect: Rect2i, amount: int) -> Rect2i:
	return Rect2i(
		rect.position - Vector2i(amount, amount),
		rect.size + Vector2i(amount * 2, amount * 2)
	)

static func intersects_any(rect: Rect2i, others: Array[Rect2i]) -> bool:
	for other in others:
		if rect.intersects(other):
			return true
	return false

static func ellipse_points(
	center: Vector2,
	radius: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(
			center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		)
	return points
