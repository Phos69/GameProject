extends GutTest
## Progression A7 — Downed/revive multi-modalità e helper PlayerQuery.
##
## Migra e accorpa:
##   tests/milestone_16_downed_revive_smoke_test.gd  (main.tscn, multiplayer)
##   tests/player_query_smoke_test.gd                (player sintetici)

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")
const PlayerStub = preload("res://tests/support/player_stub.gd")

var _survival_defeat_count: int = 0
var _dungeon_defeat_count: int = 0
var _defense_defeat_count: int = 0

# --- downed/revive attraverso survival/dungeon/tower (milestone_16) ---------

func test_downed_revive_flow() -> void:
	_survival_defeat_count = 0
	_dungeon_defeat_count = 0
	_defense_defeat_count = 0
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(3)

	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var revive_system := scene.node(&"revive_system")
	var survival_mode := scene.node(&"survival_mode") as SurvivalMode
	var dungeon_mode := scene.node(&"dungeon_mode") as DungeonMode
	var tower_mode := scene.node(&"tower_defense_mode") as TowerDefenseMode
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var input_manager := scene.node(&"input_manager") as InputManager
	if game_mode_manager == null or local_multiplayer == null or player_manager == null or revive_system == null or survival_mode == null or dungeon_mode == null or tower_mode == null or wave_manager == null or input_manager == null:
		assert_true(false, "downed/revive systems are available")
		scene.teardown()
		return

	survival_mode.survival_defeated.connect(_on_survival_defeated)
	dungeon_mode.dungeon_defeated.connect(_on_dungeon_defeated)
	tower_mode.defense_defeated.connect(_on_defense_defeated)
	wave_manager.initial_delay = 100.0
	local_multiplayer.activate_slot(2)
	await wait_frames(1)
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	if player_one == null or player_two == null:
		assert_true(false, "two players are active")
		_teardown(scene, local_multiplayer)
		return

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_frames(1)
	player_one.global_position = Vector2.ZERO
	player_two.global_position = Vector2(40.0, 0.0)
	player_two.prepare_for_run(ProgressionManager.FIELD_KIT_HEALTH_BONUS)
	var player_two_health := player_two.health_component
	assert_eq(player_two_health.max_health, 120, "Field Kit configures max health before the downed flow")
	player_two_health.apply_damage(9999)
	assert_true(player_two_health.is_downed, "lethal player damage enters downed state")
	assert_false(player_two_health.is_dead, "downed is distinct from dead")
	assert_false(player_two_health.is_alive(), "downed players are excluded from living target selection")
	assert_true(player_two.visual.is_downed, "player visual shows the downed pose")
	assert_true(player_two.revive_indicator.visible, "world-space revive indicator remains visible")
	assert_false(player_two.aim_line.visible, "downed players cannot present an active aim line")

	revive_system.set("revive_duration", 1.0)
	assert_false(bool(revive_system.call("advance_revive", player_two, player_one, 0.4)), "partial revive does not complete")
	assert_true(is_equal_approx(float(revive_system.call("get_revive_progress", player_two)), 0.4), "partial revive exposes deterministic progress")
	revive_system.call("interrupt_revive", player_two)
	assert_true(is_zero_approx(float(revive_system.call("get_revive_progress", player_two))), "interrupted revive resets progress immediately")
	revive_system.call("advance_revive", player_two, player_one, 0.6)
	assert_true(bool(revive_system.call("advance_revive", player_two, player_one, 0.5)), "holding interact long enough completes the revive")
	assert_true(player_two_health.is_alive(), "revived player becomes alive")
	assert_eq(player_two_health.current_health, 42, "revive restores 35 percent of Field Kit health")
	assert_eq(player_two_health.max_health, 120, "revive does not stack the Field Kit bonus")
	assert_false(player_two.revive_indicator.visible, "revive indicator hides after completion")
	player_two.prepare_for_run(ProgressionManager.FIELD_KIT_HEALTH_BONUS)
	assert_eq(player_two_health.max_health, 120, "subsequent run preparation remains idempotent")

	local_multiplayer.activate_slot(3)
	await wait_frames(1)
	var player_three := player_manager.players.get(3) as PlayerController
	assert_not_null(player_three, "a third player can join during the run")
	if player_three != null:
		player_two.global_position = Vector2.ZERO
		player_three.global_position = Vector2(30.0, 0.0)
		player_two_health.apply_damage(9999)
		revive_system.call("advance_revive", player_two, player_three, 0.3)
		local_multiplayer.deactivate_slot(3)
		await wait_frames(1)
		revive_system.call("interrupt_revive", player_two)
		assert_true(is_zero_approx(float(revive_system.call("get_revive_progress", player_two))), "reviver leave cannot complete a stale revive")
		player_two_health.revive(60)

	assert_true(input_manager.has_method("is_player_interact_pressed"), "revive uses the shared held interact action")

	player_one.health_component.apply_damage(9999)
	player_two.health_component.apply_damage(9999)
	await wait_frames(5)
	assert_true(_survival_defeat_count == 1 and not survival_mode.is_running, "survival ends only when every active player is incapacitated")

	game_mode_manager.set_mode(GameConstants.MODE_DUNGEON, {"seed": 16, "room_count": 4})
	await wait_frames(1)
	player_one.health_component.apply_damage(9999)
	player_two.health_component.apply_damage(9999)
	await wait_frames(5)
	assert_true(_dungeon_defeat_count == 1 and not dungeon_mode.is_running, "dungeon ends when the whole party is incapacitated")

	game_mode_manager.set_mode(GameConstants.MODE_TOWER_DEFENSE, {"initial_delay": 100.0})
	await wait_frames(1)
	player_one.health_component.apply_damage(9999)
	player_two.health_component.apply_damage(9999)
	await wait_frames(5)
	assert_true(_defense_defeat_count == 1 and tower_mode.state == TowerDefenseWaveController.State.DEFEATED, "tower defense also resolves an all-downed party")

	_teardown(scene, local_multiplayer)

func _teardown(scene: MainSceneFixture, local_multiplayer: LocalMultiplayerManager) -> void:
	if local_multiplayer != null:
		local_multiplayer.deactivate_slot(3)
		local_multiplayer.deactivate_slot(2)
	scene.teardown()
	await wait_frames(1)

# --- helper condiviso PlayerQuery (player_query) ----------------------------

func test_player_query() -> void:
	var p_alive := _make_stub_player(1, Vector2(0, 0))
	var p_downed := _make_stub_player(2, Vector2(100, 0))
	var p_dead := _make_stub_player(3, Vector2(3, 0))
	PlayerQuery.health_component(p_downed).is_downed = true
	PlayerQuery.health_component(p_dead).is_dead = true
	await wait_frames(1)
	var tree := get_tree()

	assert_eq(PlayerQuery.all(tree).size(), 3, "all() ritorna tutti i player")
	assert_true(PlayerQuery.is_alive(p_alive), "player vivo riconosciuto")
	assert_false(PlayerQuery.is_alive(p_downed), "player downed non e vivo")
	assert_false(PlayerQuery.is_alive(p_dead), "player morto non e vivo")
	assert_true(PlayerQuery.is_downed(p_downed), "player downed riconosciuto")
	assert_false(PlayerQuery.is_downed(p_alive), "player vivo non e downed")
	assert_true(PlayerQuery.is_incapacitated(p_downed), "downed e incapacitato")
	assert_true(PlayerQuery.is_incapacitated(p_dead), "morto e incapacitato")
	assert_false(PlayerQuery.is_incapacitated(p_alive), "vivo non e incapacitato")
	assert_true(PlayerQuery.any_alive(tree), "any_alive vero con un vivo")

	var alive := PlayerQuery.alive(tree)
	assert_true(alive.size() == 1 and alive[0] == p_alive, "alive() solo il vivo")
	var downed := PlayerQuery.downed(tree)
	assert_true(downed.size() == 1 and downed[0] == p_downed, "downed() solo il downed")

	var query_pos := Vector2(4, 0)
	assert_eq(PlayerQuery.nearest(tree, query_pos), p_alive, "nearest() salta i non vivi")
	assert_eq(PlayerQuery.nearest(tree, query_pos, false), p_dead, "nearest(alive_only=false) include i non vivi")
	assert_true(is_equal_approx(PlayerQuery.nearest_distance_squared(tree, query_pos), 16.0), "nearest_distance_squared misura il vivo")

	assert_eq(PlayerQuery.by_slot(tree, 2), p_downed, "by_slot trova lo slot")
	assert_null(PlayerQuery.by_slot(tree, 9), "by_slot slot assente -> null")
	assert_true(PlayerQuery.all(null).is_empty(), "all(null) e vuoto")
	assert_null(PlayerQuery.health_component(null), "health_component(null) null")

	p_alive.free()
	p_downed.free()
	p_dead.free()
	await wait_frames(1)

func _make_stub_player(slot: int, position: Vector2) -> Node2D:
	var player := PlayerStub.new()
	player.name = "Player%d" % slot
	player.position = position
	player.player_slot = slot
	player.add_to_group(PlayerQuery.PLAYERS_GROUP)
	var health := HealthComponent.new()
	health.name = PlayerQuery.HEALTH_COMPONENT_NODE
	player.add_child(health)
	add_child(player)
	return player

# --- signal handler ---------------------------------------------------------

func _on_survival_defeated(_wave_index: int) -> void:
	_survival_defeat_count += 1

func _on_dungeon_defeated(_room_index: int) -> void:
	_dungeon_defeat_count += 1

func _on_defense_defeated(_wave_index: int) -> void:
	_defense_defeat_count += 1
