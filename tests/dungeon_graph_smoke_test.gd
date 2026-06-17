extends SceneTree

# Milestone 5 - Dungeon ramificato.
# Verifica le proprieta del grafo generato su molti seed: ramo reale (scelta tra
# due stanze), boss sempre raggiungibile, presenza di shop, determinismo e grid
# senza sovrapposizioni.

var failures: PackedStringArray = []

func _initialize() -> void:
	var generator := DungeonGenerator.new()
	root.add_child(generator)

	var seeds: Array[int] = [101, 202, 303, 404, 505, 606, 707, 808]
	for seed_value in seeds:
		for room_count in [6, 8, 10]:
			_check_layout(generator, seed_value, room_count)

	# A tiny layout (no branch) must still be valid and boss-reachable.
	var tiny := generator.generate_layout(999, 4)
	_expect(tiny.size() == 4, "minimum room count is respected")
	_expect(DungeonGenerator.boss_is_always_reachable(tiny), "tiny dungeon keeps boss reachable")

	generator.queue_free()
	_finish()

func _check_layout(generator: DungeonGenerator, seed_value: int, room_count: int) -> void:
	var label := "seed %d / %d rooms" % [seed_value, room_count]
	var layout := generator.generate_layout(seed_value, room_count)
	var again := generator.generate_layout(seed_value, room_count)
	_expect(layout.size() == room_count, "%s: total room count respected" % label)
	_expect(_layouts_equal(layout, again), "%s: same seed is deterministic" % label)
	_expect(_count_kind(layout, DungeonGenerator.KIND_START) == 1, "%s: exactly one start" % label)
	_expect(_count_kind(layout, DungeonGenerator.KIND_BOSS) == 1, "%s: exactly one boss" % label)
	_expect(_count_kind(layout, DungeonGenerator.KIND_SHOP) >= 1, "%s: at least one shop" % label)
	_expect(_has_branch(layout), "%s: at least one room offers a real choice" % label)
	_expect(DungeonGenerator.boss_is_always_reachable(layout), "%s: boss reachable from every room" % label)
	_expect(_grids_unique(layout), "%s: room grid cells do not overlap" % label)

func _count_kind(rooms: Array[Dictionary], kind: StringName) -> int:
	var count := 0
	for room in rooms:
		if StringName(room.get("kind", &"")) == kind:
			count += 1
	return count

func _has_branch(rooms: Array[Dictionary]) -> bool:
	for room in rooms:
		if (room.get("forward", []) as Array).size() >= 2:
			return true
	return false

func _grids_unique(rooms: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for room in rooms:
		var grid := room.get("grid", Vector2i.ZERO) as Vector2i
		if seen.has(grid):
			return false
		seen[grid] = true
	return true

func _layouts_equal(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if StringName(a[index].get("kind", &"")) != StringName(b[index].get("kind", &"")):
			return false
		if (a[index].get("grid", Vector2i.ZERO) as Vector2i) != (b[index].get("grid", Vector2i.ZERO) as Vector2i):
			return false
		if (a[index].get("forward", []) as Array) != (b[index].get("forward", []) as Array):
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("DUNGEON_GRAPH_SMOKE_TEST: PASS")
		quit(0)
		return
	print("DUNGEON_GRAPH_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
