extends Node
class_name DungeonGenerator

signal dungeon_generated(rooms: Array[Dictionary])

@export_range(4, 20) var default_room_count: int = 7

func _ready() -> void:
	add_to_group("dungeon_generator")

func generate_layout(seed_value: int = 0, room_count: int = -1) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	var resolved_seed := seed_value
	if resolved_seed == 0:
		rng.randomize()
		resolved_seed = rng.seed
	else:
		rng.seed = resolved_seed

	var count := maxi(default_room_count if room_count <= 0 else room_count, 4)
	var rooms: Array[Dictionary] = []
	var cursor := Vector2i.ZERO
	var horizontal_direction := Vector2i.RIGHT if rng.randi_range(0, 1) == 0 else Vector2i.LEFT
	var vertical_direction := Vector2i.DOWN if rng.randi_range(0, 1) == 0 else Vector2i.UP
	var loot_index := clampi(roundi(float(count - 1) * 0.60), 2, count - 2)

	for index in range(count):
		var kind: StringName = &"combat"
		if index == 0:
			kind = &"start"
		elif index == count - 1:
			kind = &"boss"
		elif index == loot_index:
			kind = &"loot"

		rooms.append({
			"id": index,
			"sequence_index": index,
			"kind": kind,
			"grid": cursor,
			"links": [],
			"seed": resolved_seed
		})
		if rng.randf() < 0.58:
			cursor += horizontal_direction
		else:
			cursor += vertical_direction

	for index in range(rooms.size()):
		var links: Array[int] = []
		if index > 0:
			links.append(index - 1)
		if index < rooms.size() - 1:
			links.append(index + 1)
		rooms[index]["links"] = links

	dungeon_generated.emit(rooms)
	return rooms
