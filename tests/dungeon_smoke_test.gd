extends SceneTree

# Milestone 5 - Dungeon ramificato, shop e biomi dedicati.
# Verifica: grafo deterministico con ramo reale, traversata con scelta stanza,
# clear combat con run credit, shop che spende credit riusando DropSystem,
# percorso al boss sempre raggiungibile e completamento corretto.

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
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	for required in [game_mode_manager, survival_mode, dungeon_mode, dungeon_generator, enemy_system, player_manager, health_system, boss_system, hud]:
		_expect(required != null, "required system available")
	if (
		game_mode_manager == null or survival_mode == null or dungeon_mode == null
		or dungeon_generator == null or enemy_system == null or player_manager == null
		or health_system == null or boss_system == null or hud == null
	):
		_finish()
		return

	# Generator: branching graph, deterministic, boss reachable.
	var layout_a := dungeon_generator.generate_layout(4242, 8)
	var layout_b := dungeon_generator.generate_layout(4242, 8)
	_expect(layout_a.size() == 8, "requested room count is respected")
	_expect(StringName(layout_a[0]["kind"]) == &"start", "first room is a start room")
	_expect(DungeonGenerator.get_boss_room_id(layout_a) >= 0, "layout has a boss room")
	_expect(DungeonGenerator.boss_is_always_reachable(layout_a), "boss is reachable from every room")
	_expect(_has_branch(layout_a), "the layout offers a real choice between two rooms")
	_expect(_count_kind(layout_a, &"shop") >= 1, "the layout contains a shop room")

	dungeon_mode.combat_base_enemy_count = 2
	dungeon_mode.combat_enemy_growth = 1
	dungeon_mode.room_entered.connect(_on_room_entered)
	dungeon_mode.room_cleared.connect(_on_room_cleared)
	dungeon_mode.dungeon_completed.connect(_on_dungeon_completed)
	game_mode_manager.set_mode(GameConstants.MODE_DUNGEON, {"seed": 4242, "room_count": 8})
	await process_frame
	await physics_frame

	_expect(dungeon_mode.is_running, "dungeon mode starts")
	_expect(not survival_mode.is_running, "starting dungeon stops survival")
	_expect(dungeon_mode.run_seed == 4242, "dungeon exposes the active seed")
	_expect(StringName(dungeon_mode.get_current_room_data().get("kind", &"")) == &"start", "run begins in the start room")
	_expect(not dungeon_mode.active_room.is_locked, "the start room exit is open")
	_expect("Procedural Dungeon" in hud.status_label.text, "HUD switches to dungeon status")
	_expect("Seed 4242" in hud.status_label.text, "HUD displays the dungeon seed")
	_expect("Map" in hud.status_label.text, "HUD shows the dungeon path map")

	var player_one := player_manager.players.get(1) as PlayerController
	_expect(player_one != null, "player one is available in the dungeon")
	if player_one == null:
		_finish()
		return

	# First transition via the physical exit portal (start room -> first forward).
	var first_target := dungeon_mode.get_forward_options()[0]
	player_one.global_position = dungeon_mode.active_room.get_exit_position_for_target(first_target)
	_expect(
		await _wait_for_room(dungeon_mode, first_target),
		"walking the exit portal advances to the chosen room"
	)

	# Graph walk to the boss, diverting through the shop once to test purchases.
	var visited_shop := false
	var guard := 0
	while StringName(dungeon_mode.get_current_room_data().get("kind", &"")) != &"boss" and guard < 40:
		guard += 1
		var kind := StringName(dungeon_mode.get_current_room_data().get("kind", &""))
		if kind == &"combat":
			_kill_room_enemies(dungeon_mode, health_system)
			_expect(await _wait_for_room_unlocked(dungeon_mode), "combat room unlocks after clearing")
		if kind == &"shop" and not visited_shop:
			visited_shop = true
			await _test_shop(dungeon_mode, player_one)

		var forward := dungeon_mode.get_forward_options()
		_expect(not forward.is_empty(), "non-boss room has a forward path")
		if forward.is_empty():
			break
		var target := forward[0]
		if not visited_shop:
			for option in forward:
				if StringName(dungeon_mode.layout[option].get("kind", &"")) == &"shop":
					target = option
		if forward.size() >= 2:
			_expect(dungeon_mode.choose_next_room(target), "branch room accepts a real room choice")
		else:
			_expect(dungeon_mode.choose_next_room(target), "open room advances along the path")
		await process_frame
		await physics_frame

	_expect(visited_shop, "the walk visited the shop branch")
	_expect(StringName(dungeon_mode.get_current_room_data().get("kind", &"")) == &"boss", "the path reaches the boss room")
	_expect(dungeon_mode.active_room.is_locked, "boss room locks its exit")
	var boss := boss_system.get_active_boss()
	_expect(boss != null, "boss room requests a shared boss")
	if boss != null:
		boss.set_physics_process(false)
		health_system.apply_damage(boss, 99999)
		_expect(await _wait_for_room_unlocked(dungeon_mode), "boss defeat unlocks the final exit")

	_expect(dungeon_mode.request_next_room(), "the final exit completes the run")
	_expect(dungeon_mode.current_room_state == &"complete", "dungeon enters complete state")
	_expect(completed_runs.has(4242), "dungeon completion reports the seed")

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	_expect(not dungeon_mode.is_running, "leaving dungeon stops its runtime")
	_expect(survival_mode.is_running, "survival can restart after the dungeon")
	survival_mode.stop_mode()
	_finish()

func _test_shop(dungeon_mode: DungeonMode, buyer: Node) -> void:
	var offers := dungeon_mode.get_shop_offers()
	_expect(offers.size() >= 2, "shop presents at least two offers")
	var credits_before := dungeon_mode.run_credits
	var cheapest_index := 0
	for index in range(offers.size()):
		if int(offers[index].get("cost", 0)) < int(offers[cheapest_index].get("cost", 0)):
			cheapest_index = index
	var cost := int(offers[cheapest_index].get("cost", 0))
	var pickups_before := get_nodes_in_group("drop_pickups").size()
	_expect(dungeon_mode.purchase_offer(cheapest_index, buyer), "an affordable offer can be purchased")
	_expect(dungeon_mode.run_credits == credits_before - cost, "purchase spends exactly the offer cost")
	await process_frame
	_expect(get_nodes_in_group("drop_pickups").size() > pickups_before, "purchase spawns the reward through DropSystem")
	_expect(not dungeon_mode.purchase_offer(cheapest_index, buyer), "a sold offer cannot be bought again")
	# Drain credits and confirm an unaffordable purchase is rejected.
	dungeon_mode.run_credits = 0
	var other_index := (cheapest_index + 1) % offers.size()
	_expect(not dungeon_mode.purchase_offer(other_index, buyer), "an unaffordable offer is rejected")

func _has_branch(rooms: Array[Dictionary]) -> bool:
	for room in rooms:
		if (room.get("forward", []) as Array).size() >= 2:
			return true
	return false

func _count_kind(rooms: Array[Dictionary], kind: StringName) -> int:
	var count := 0
	for room in rooms:
		if StringName(room.get("kind", &"")) == kind:
			count += 1
	return count

func _kill_room_enemies(dungeon_mode: DungeonMode, health_system: HealthSystem) -> void:
	for enemy in dungeon_mode.room_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		enemy.set_physics_process(false)
		health_system.apply_damage(enemy, 99999)

func _wait_for_room(dungeon_mode: DungeonMode, room_index: int) -> bool:
	for _frame in range(120):
		if dungeon_mode.current_room_index == room_index:
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
