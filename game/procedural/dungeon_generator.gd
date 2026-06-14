extends Node
class_name DungeonGenerator

signal dungeon_generated(rooms: Array[Dictionary])

@export var default_room_count: int = 8

func _ready() -> void:
	add_to_group("dungeon_generator")

func generate_layout(seed_value: int = 0, room_count: int = -1) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	var count := default_room_count if room_count <= 0 else room_count
	var rooms: Array[Dictionary] = []
	var cursor := Vector2i.ZERO
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for index in range(count):
		var kind: StringName = &"combat"
		if index == 0:
			kind = &"start"
		elif index == count - 1:
			kind = &"boss"
		elif index % 4 == 0:
			kind = &"loot"

		rooms.append({
			"id": index,
			"kind": kind,
			"grid": cursor,
			"links": []
		})
		cursor += directions[rng.randi_range(0, directions.size() - 1)]

	for index in range(rooms.size()):
		var links: Array[int] = []
		if index > 0:
			links.append(index - 1)
		if index < rooms.size() - 1:
			links.append(index + 1)
		rooms[index]["links"] = links

	dungeon_generated.emit(rooms)
	return rooms

