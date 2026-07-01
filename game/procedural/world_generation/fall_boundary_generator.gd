extends RefCounted
class_name FallBoundaryGenerator

const IsoGridConfig = preload("res://game/core/iso_grid_config.gd")

const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]
const FALL_THICKNESS := IsoGridConfig.FALL_BOUNDARY_THICKNESS_TILES

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
	layout.add_fall_zone_rect(rect, side)
