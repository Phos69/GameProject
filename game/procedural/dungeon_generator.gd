extends Node
class_name DungeonGenerator

signal dungeon_generated(rooms: Array[Dictionary])

@export_range(4, 20) var default_room_count: int = 7

# Room kinds the dungeon understands. start and boss are always present and the
# boss room must stay reachable from every other room.
const KIND_START: StringName = &"start"
const KIND_COMBAT: StringName = &"combat"
const KIND_LOOT: StringName = &"loot"
const KIND_SHOP: StringName = &"shop"
const KIND_REST: StringName = &"rest"
const KIND_BOSS: StringName = &"boss"

func _ready() -> void:
	add_to_group("dungeon_generator")

# Builds a branching directed acyclic graph of rooms. A linear spine guarantees
# the boss is always reachable; one branch room offers a real choice between two
# rooms (e.g. fight the spine combat room or detour through the shop) that merge
# back onto the spine before the boss.
func generate_layout(seed_value: int = 0, room_count: int = -1) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	var resolved_seed := seed_value
	if resolved_seed == 0:
		rng.randomize()
		resolved_seed = rng.seed
	else:
		rng.seed = resolved_seed

	var total := maxi(default_room_count if room_count <= 0 else room_count, 4)
	var has_branch := total >= 5
	var spine_len := total - (1 if has_branch else 0)

	var rooms: Array[Dictionary] = []
	var cursor := Vector2i.ZERO
	for index in range(spine_len):
		rooms.append({
			"id": index,
			"sequence_index": index,
			"depth": index,
			"kind": KIND_COMBAT,
			"grid": cursor,
			"forward": [] as Array[int],
			"back": [] as Array[int],
			"links": [] as Array[int],
			"seed": resolved_seed
		})
		cursor += Vector2i.RIGHT
	rooms[0]["kind"] = KIND_START
	rooms[spine_len - 1]["kind"] = KIND_BOSS

	var loot_index := clampi(roundi(float(spine_len - 1) * 0.6), 1, spine_len - 2)
	rooms[loot_index]["kind"] = KIND_LOOT
	var rest_index := clampi(roundi(float(spine_len - 1) * 0.35), 1, spine_len - 2)
	if rest_index != loot_index:
		rooms[rest_index]["kind"] = KIND_REST

	for index in range(spine_len - 1):
		(rooms[index]["forward"] as Array[int]).append(index + 1)
		(rooms[index + 1]["back"] as Array[int]).append(index)

	if has_branch:
		var branch_at := clampi(1 + rng.randi_range(0, maxi(spine_len - 4, 0)), 1, spine_len - 3)
		var alt_index := spine_len
		var alt_grid := Vector2i(branch_at + 1, 1)
		rooms.append({
			"id": alt_index,
			"sequence_index": branch_at + 1,
			"depth": branch_at + 1,
			"kind": KIND_SHOP,
			"grid": alt_grid,
			"forward": [branch_at + 2] as Array[int],
			"back": [branch_at] as Array[int],
			"links": [] as Array[int],
			"seed": resolved_seed
		})
		(rooms[branch_at]["forward"] as Array[int]).append(alt_index)
		(rooms[branch_at + 2]["back"] as Array[int]).append(alt_index)
		# The spine alternative to the shop is a tangible fight so the choice is
		# meaningful; never override a loot/rest room placed on that spine cell.
		if StringName(rooms[branch_at + 1]["kind"]) == KIND_COMBAT:
			rooms[branch_at + 1]["kind"] = KIND_COMBAT

	for room in rooms:
		room["links"] = (room["forward"] as Array[int]).duplicate()

	dungeon_generated.emit(rooms)
	return rooms

# Returns the boss room id, or -1 if the layout has none.
static func get_boss_room_id(rooms: Array[Dictionary]) -> int:
	for room in rooms:
		if StringName(room.get("kind", &"")) == KIND_BOSS:
			return int(room.get("id", -1))
	return -1

# True when every room can still reach the boss room by following forward links.
static func boss_is_always_reachable(rooms: Array[Dictionary]) -> bool:
	var boss_id := get_boss_room_id(rooms)
	if boss_id < 0:
		return false
	var by_id: Dictionary = {}
	for room in rooms:
		by_id[int(room.get("id", -1))] = room
	for room in rooms:
		if not _can_reach(int(room.get("id", -1)), boss_id, by_id):
			return false
	return true

static func _can_reach(from_id: int, target_id: int, by_id: Dictionary) -> bool:
	var visited: Dictionary = {}
	var queue: Array[int] = [from_id]
	visited[from_id] = true
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == target_id:
			return true
		var room := by_id.get(current, {}) as Dictionary
		for next_id in (room.get("forward", []) as Array):
			var typed_next := int(next_id)
			if not visited.has(typed_next):
				visited[typed_next] = true
				queue.append(typed_next)
	return false
