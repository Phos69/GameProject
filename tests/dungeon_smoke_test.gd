extends SceneTree

var failures: PackedStringArray = []
var entered_rooms: Array[int] = []
var cleared_rooms: Array[int] = []
var completed_runs: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var dungeon_mode := get_first_node_in_group("dungeon_mode") as DungeonMode
	var dungeon_generator := get_first_node_in_group("dungeon_generator") as DungeonGenerator
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(dungeon_mode != null, "dungeon mode is registered")
	_expect(dungeon_generator != null, "dungeon generator is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	_expect(boss_system != null, "boss system is available")
	_expect(hud != null, "HUD manager is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or dungeon_mode == null
		or dungeon_generator == null
		or wave_manager == null
		or enemy_system == null
		or player_manager == null
		or health_system == null
		or boss_system == null
		or hud == null
	):
		_finish()
		return

	var layout_a := dungeon_generator.generate_layout(4242, 6)
	var layout_b := dungeon_generator.generate_layout(4242, 6)
	_expect(layout_a == layout_b, "the same seed generates the same layout")
	_expect(layout_a.size() == 6, "requested room count is respected")
	_expect(_has_unique_grid_cells(layout_a), "generated rooms do not overlap")
	_expect(StringName(layout_a[0]["kind"]) == &"start", "the first room is a start room")
	_expect(StringName(layout_a[-1]["kind"]) == &"boss", "the final room is a boss room")
	_expect(_count_room_kind(layout_a, &"loot") == 1, "the layout contains one loot room")
	_expect(_links_are_sequential(layout_a), "room links form a traversable sequence")

	wave_manager.base_enemy_count = 1
	wave_manager.initial_delay = 0.0
	wave_manager.spawn_interval = 0.0
	wave_manager.state_timer = 0.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	_expect(
		await _wait_for_survival_combat(wave_manager),
		"survival has an active enemy before the mode switch"
	)

	dungeon_mode.combat_base_enemy_count = 2
	dungeon_mode.combat_enemy_growth = 1
	dungeon_mode.room_entered.connect(_on_room_entered)
	dungeon_mode.room_cleared.connect(_on_room_cleared)
	dungeon_mode.dungeon_completed.connect(_on_dungeon_completed)
	game_mode_manager.set_mode(
		GameConstants.MODE_DUNGEON,
		{"seed": 4242, "room_count": 6}
	)
	await process_frame
	await physics_frame

	_expect(dungeon_mode.is_running, "dungeon mode starts")
	_expect(not survival_mode.is_running, "starting dungeon stops survival")
	_expect(enemy_system.get_active_enemies().is_empty(), "mode switch clears survival enemies")
	_expect(dungeon_mode.run_seed == 4242, "dungeon exposes the active seed")
	_expect(dungeon_mode.layout.size() == 6, "dungeon stores the generated layout")
	_expect(dungeon_mode.current_room_index == 0, "the run starts in room zero")
	_expect(not dungeon_mode.active_room.is_locked, "the start room exit is open")
	_expect("Procedural Dungeon" in hud.status_label.text, "HUD switches to dungeon status")
	_expect("Seed 4242" in hud.status_label.text, "HUD displays the dungeon seed")

	var player_one := player_manager.players.get(1) as PlayerController
	_expect(player_one != null, "player one is available in the dungeon")
	if player_one == null:
		_finish()
		return

	player_one.global_position = dungeon_mode.active_room.get_exit_position()
	_expect(
		await _wait_for_room_index(dungeon_mode, 1),
		"entering the open portal advances to the first combat room"
	)
	_expect(dungeon_mode.active_room.is_locked, "combat room locks its exit")
	_expect(not dungeon_mode.request_next_room(), "locked rooms reject transitions")
	_expect(dungeon_mode.get_enemies_remaining() == 2, "first combat room spawns two enemies")

	while dungeon_mode.current_room_index < dungeon_mode.layout.size() - 1:
		var room_kind := StringName(dungeon_mode.get_current_room_data().get("kind", &""))
		match room_kind:
			&"combat":
				var expected_room := dungeon_mode.current_room_index
				_kill_room_enemies(dungeon_mode, health_system)
				_expect(
					await _wait_for_room_unlocked(dungeon_mode),
					"combat room unlocks after all tracked enemies die"
				)
				_expect(cleared_rooms.has(expected_room), "combat room emits room_cleared")
			&"loot":
				_expect(not dungeon_mode.active_room.is_locked, "loot room exit starts open")
				_expect(dungeon_mode.room_pickups.size() == 4, "loot room spawns four guaranteed pickups")

		_expect(dungeon_mode.request_next_room(), "an open exit advances the dungeon")
		await process_frame
		await physics_frame

	_expect(
		StringName(dungeon_mode.get_current_room_data().get("kind", &"")) == &"boss",
		"the traversable path ends in the boss room"
	)
	_expect(dungeon_mode.active_room.is_locked, "boss room locks its exit")
	var boss := boss_system.get_active_boss() as BasicBoss
	_expect(boss != null, "boss room requests a shared boss")
	if boss != null:
		boss.set_physics_process(false)
		health_system.apply_damage(boss, 9999)
		_expect(
			await _wait_for_room_unlocked(dungeon_mode),
			"boss defeat unlocks the final exit"
		)

	_expect(dungeon_mode.request_next_room(), "the final exit completes the run")
	_expect(dungeon_mode.current_room_state == &"complete", "dungeon enters complete state")
	_expect(completed_runs.has(4242), "dungeon completion signal reports the seed")
	_expect(entered_rooms.size() == 6, "every generated room was entered")

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	_expect(not dungeon_mode.is_running, "leaving dungeon stops its runtime")
	_expect(survival_mode.is_running, "survival can restart after the dungeon")
	_expect(
		(get_first_node_in_group("prototype_arena_content") as CanvasItem).visible,
		"prototype arena becomes visible again"
	)
	survival_mode.stop_mode()
	_finish()

func _has_unique_grid_cells(rooms: Array[Dictionary]) -> bool:
	var occupied: Dictionary = {}
	for room in rooms:
		var grid := room.get("grid", Vector2i.ZERO) as Vector2i
		if occupied.has(grid):
			return false
		occupied[grid] = true
	return true

func _count_room_kind(rooms: Array[Dictionary], kind: StringName) -> int:
	var count := 0
	for room in rooms:
		if StringName(room.get("kind", &"")) == kind:
			count += 1
	return count

func _links_are_sequential(rooms: Array[Dictionary]) -> bool:
	for index in range(rooms.size()):
		var expected: Array[int] = []
		if index > 0:
			expected.append(index - 1)
		if index < rooms.size() - 1:
			expected.append(index + 1)
		if rooms[index].get("links", []) != expected:
			return false
	return true

func _kill_room_enemies(
	dungeon_mode: DungeonMode,
	health_system: HealthSystem
) -> void:
	for enemy in dungeon_mode.room_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		enemy.set_physics_process(false)
		health_system.apply_damage(enemy, 9999)

func _wait_for_room_index(dungeon_mode: DungeonMode, room_index: int) -> bool:
	for _frame in range(120):
		if dungeon_mode.current_room_index == room_index:
			return true
		await physics_frame
	return false

func _wait_for_survival_combat(wave_manager: WaveManager) -> bool:
	for _frame in range(120):
		if (
			wave_manager.state == &"combat"
			and not wave_manager.get_active_wave_enemies().is_empty()
		):
			return true
		await physics_frame
	return false

func _wait_for_room_unlocked(dungeon_mode: DungeonMode) -> bool:
	for _frame in range(120):
		if dungeon_mode.active_room != null and not dungeon_mode.active_room.is_locked:
			return true
		await physics_frame
	return false

func _on_room_entered(room_index: int, _room_data: Dictionary) -> void:
	entered_rooms.append(room_index)

func _on_room_cleared(room_index: int, _room_data: Dictionary) -> void:
	cleared_rooms.append(room_index)

func _on_dungeon_completed(seed_value: int, _room_count: int) -> void:
	completed_runs.append(seed_value)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("DUNGEON_SMOKE_TEST: PASS")
		quit(0)
		return
	print("DUNGEON_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
