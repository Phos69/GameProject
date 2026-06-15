extends Node
class_name FallBoundaryGenerator

const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]
const FALL_THICKNESS := 6

func apply_fall_boundaries(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> void:
	if cell == null or layout == null:
		return
	for side in SIDES:
		if cell.get_border(side) != BiomeCell.BorderType.FALL:
			continue
		_add_fall_boundary(layout, side)

func _add_fall_boundary(
	layout: BiomeEnvironmentLayout,
	side: StringName
) -> void:
	var zone_size := layout.zone_size
	var rect := Rect2i()
	match side:
		&"north":
			rect = Rect2i(Vector2i(0, 0), Vector2i(zone_size.x, FALL_THICKNESS))
		&"south":
			rect = Rect2i(
				Vector2i(0, zone_size.y - FALL_THICKNESS),
				Vector2i(zone_size.x, FALL_THICKNESS)
			)
		&"west":
			rect = Rect2i(Vector2i(0, 0), Vector2i(FALL_THICKNESS, zone_size.y))
		_:
			rect = Rect2i(
				Vector2i(zone_size.x - FALL_THICKNESS, 0),
				Vector2i(FALL_THICKNESS, zone_size.y)
			)
	layout.fall_zone_rects.append(rect)
	layout.hazard_rects.append(rect)
	layout.hazard_ids.append(&"fall_zone")
	layout.hazard_positions.append(layout.rect_center_to_world(rect))
	layout.hazard_sizes.append(layout.rect_size_to_world(rect))
	layout.hazard_rotations.append(0.0)
