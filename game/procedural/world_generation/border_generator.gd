extends Node
class_name BorderGenerator

const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]

func configure_borders(cells: Array[BiomeCell]) -> void:
	var cells_by_grid := {}
	for cell in cells:
		cells_by_grid[cell.grid] = cell

	for cell in cells:
		for side in SIDES:
			var neighbor := cells_by_grid.get(
				cell.grid + get_side_offset(side),
				null
			) as BiomeCell
			cell.set_neighbor(side, neighbor)

static func get_side_offset(side: StringName) -> Vector2i:
	match side:
		&"north":
			return Vector2i(0, -1)
		&"south":
			return Vector2i(0, 1)
		&"west":
			return Vector2i(-1, 0)
		_:
			return Vector2i(1, 0)

static func get_opposite_side(side: StringName) -> StringName:
	match side:
		&"north":
			return &"south"
		&"south":
			return &"north"
		&"west":
			return &"east"
		_:
			return &"west"
