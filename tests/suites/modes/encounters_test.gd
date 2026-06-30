extends GutTest
## Modes A8 — Encounter casuali, mini-eventi biome, helper wave-cycle, save/flow.
##
## Migra e accorpa:
##   tests/wave_cycle_smoke_test.gd          (helper statici WaveCycle)
##   tests/random_encounter_smoke_test.gd    (RandomEncounterSystem sintetico)
##   tests/biome_mini_events_smoke_test.gd   (RandomEncounterSystem sintetico)
##   tests/milestone_9_smoke_test.gd         (main.tscn: menu/save/audio/mode)

const TEMP_SAVE_PATH := "user://m8_encounters_save_test.json"
const DROP_EXPERIENCE := &"experience"
const FIELD_KIT_UNLOCK := &"field_kit"
const MODE_DUNGEON := &"dungeon"
const MODE_MENU := &"menu"
const MODE_SURVIVAL := &"survival"
const SAVE_VERSION := 6

var _gameplay_feedback_events: Array[Dictionary] = []

# --- helper statici WaveCycle (wave_cycle) ----------------------------------

func test_wave_cycle_helpers() -> void:
	assert_true(WaveCycle.should_spawn_boss(5, 5), "wave 5 con intervallo 5 e boss")
	assert_true(WaveCycle.should_spawn_boss(10, 5), "wave 10 con intervallo 5 e boss")
	assert_false(WaveCycle.should_spawn_boss(4, 5), "wave 4 non e boss")
	assert_false(WaveCycle.should_spawn_boss(0, 5), "wave 0 non e mai boss")
	assert_false(WaveCycle.should_spawn_boss(5, 0), "intervallo 0 disabilita i boss")

	var alive_node := Node.new()
	add_child(alive_node)
	assert_eq(WaveCycle.prune_node(alive_node), alive_node, "nodo vivo sopravvive al prune")
	assert_null(WaveCycle.prune_node(null), "null resta null")
	var freed_node := Node.new()
	freed_node.free()
	assert_null(WaveCycle.prune_node(freed_node), "nodo liberato -> null")

	var keep := Node.new()
	add_child(keep)
	var drop := Node.new()
	add_child(drop)
	var nodes: Array[Node] = [keep, drop]
	drop.free()
	WaveCycle.prune_nodes(nodes)
	assert_true(nodes.size() == 1 and nodes[0] == keep, "prune_nodes tiene solo i validi")

	alive_node.free()
	keep.free()

# --- encounter casuali (random_encounter) -----------------------------------

func test_random_encounter() -> void:
	var scene_root := _make_current_scene_root()
	var player := Node2D.new()
	player.add_to_group("players")
	scene_root.add_child(player)
	var crate_system = _new_script_node(
		"res://game/modes/zombie/resource_crate_system.gd"
	)
	scene_root.add_child(crate_system)
	var encounter = _new_script_node(
		"res://game/modes/zombie/random_encounter_system.gd"
	)
	scene_root.add_child(encounter)
	await wait_physics_frames(1)
	encounter.base_chance = 1.0
	encounter.danger_telegraph_duration = 0.01
	encounter.configure_seed(1234)
	var biome = load("res://game/modes/zombie/biomes/toxic_wastes.tres")

	assert_false(encounter.can_start_encounter(biome, 2, true), "encounter skips critical/boss state")
	assert_true(encounter.can_start_encounter(biome, 2, false), "encounter can start after wave one")
	var result: Dictionary = encounter.force_encounter(biome, &"survivor_cache", 2)
	assert_eq(result.get("encounter_id"), &"survivor_cache", "cache encounter")
	assert_true(result.has("threat_score"), "encounter exposes threat score")
	assert_true(_has_reward_crate(result, &"medical"), "survivor cache spawns a medical reward crate")
	assert_eq(int((result.get("tuning") as Dictionary).get("party_size", 0)), 1, "encounter tuning records active party size")
	assert_false(encounter.can_start_encounter(biome, 3, false), "encounter cooldown prevents immediate repeats")
	assert_false(encounter.can_start_encounter(biome, 4, false), "encounter cooldown spans two full waves")
	assert_true(encounter.can_start_encounter(biome, 5, false), "encounter cooldown allows later waves")
	result = encounter.force_encounter(biome, &"cursed_crate", 2)
	assert_eq(result.get("reward"), "cursed_loot", "cursed reward")
	assert_true(_has_reward_crate(result, &"biome_toxic"), "cursed crate spawns a biome reward crate")
	assert_eq(int(encounter.get_debug_snapshot().get("pending_telegraph_count", 0)), 1, "cursed crate starts a warning telegraph")
	assert_gte((result.get("position") as Vector2).distance_to(player.global_position), encounter.safe_distance * 0.75, "encounter position stays away from the player")
	result = encounter.force_encounter(biome, &"hazard_burst", 5)
	var hazard_tuning := result.get("tuning") as Dictionary
	assert_gte(int(hazard_tuning.get("hazard_count", 0)), 3, "hazard burst tuning scales hazard count")
	assert_gt(float(hazard_tuning.get("hazard_lifetime", 0.0)), 3.0, "hazard burst tuning exposes lifetime")
	assert_eq(int(encounter.get_debug_snapshot().get("pending_telegraph_count", 0)), 1, "hazard burst starts a warning telegraph")
	result = encounter.force_encounter(biome, &"toxic_leak", 6)
	var toxic_tuning := result.get("tuning") as Dictionary
	var toxic_telegraph := _find_telegraph(result)
	assert_gte(int(toxic_tuning.get("hazard_count", 0)), 3, "toxic mini-event scales hazard count")
	assert_eq(result.get("reward"), "toxic_salvage", "toxic mini-event exposes biome reward")
	assert_true(_has_reward_crate(result, &"biome_toxic"), "toxic mini-event spawns a biome reward crate")
	assert_true(toxic_telegraph != null and toxic_telegraph.encounter_id == &"toxic_leak", "toxic mini-event telegraph keeps event id")
	await get_tree().create_timer(0.05).timeout
	encounter.cleanup_encounter()
	_free_current_scene_root(scene_root)
	await wait_physics_frames(1)

# --- mini-eventi biome (biome_mini_events) ----------------------------------

func test_biome_mini_events() -> void:
	var scene_root := _make_current_scene_root()
	var player := Node2D.new()
	player.name = "FarPlayer"
	player.add_to_group("players")
	scene_root.add_child(player)
	var exposed_player := Node2D.new()
	exposed_player.name = "ExposedPlayer"
	exposed_player.add_to_group("players")
	scene_root.add_child(exposed_player)
	var visual_settings = _new_script_node(
		"res://game/visuals/visual_settings_manager.gd"
	)
	scene_root.add_child(visual_settings)
	var hazard_system = _new_script_node(
		"res://game/modes/zombie/hazard_system.gd"
	)
	scene_root.add_child(hazard_system)
	var crate_system = _new_script_node(
		"res://game/modes/zombie/resource_crate_system.gd"
	)
	scene_root.add_child(crate_system)
	var encounter = _new_script_node(
		"res://game/modes/zombie/random_encounter_system.gd"
	)
	scene_root.add_child(encounter)
	await wait_physics_frames(1)
	encounter.danger_telegraph_duration = 0.01
	encounter.configure_seed(2026)
	visual_settings.apply_profile(&"high_contrast")

	var cases := {&"toxic_wastes": &"toxic_leak", &"burning_fields": &"fire_breakout", &"frozen_outskirts": &"whiteout", &"drowned_marsh": &"marsh_emergence"}
	for biome_id in cases.keys():
		_validate_biome_event(encounter, visual_settings, StringName(biome_id), StringName(cases[biome_id]))
	await _validate_whiteout_status_is_avoidable(encounter, hazard_system, player, exposed_player)
	await get_tree().create_timer(0.05).timeout
	encounter.cleanup_encounter()
	hazard_system.stop_run()
	_free_current_scene_root(scene_root)
	await wait_physics_frames(1)

func _validate_biome_event(
	encounter,
	visual_settings,
	biome_id: StringName,
	expected_event_id: StringName
) -> void:
	var biome = load("res://game/modes/zombie/biomes/%s.tres" % String(biome_id))
	assert_not_null(biome, "%s biome loads" % String(biome_id))
	if biome == null:
		return
	assert_eq(encounter.get_biome_mini_event_id(biome_id), expected_event_id, "%s exposes its mini-event id" % String(biome_id))
	var result: Dictionary = encounter.force_encounter(biome, expected_event_id, 6)
	var tuning := result.get("tuning") as Dictionary
	var telegraph := _find_telegraph(result)
	assert_eq(result.get("encounter_id"), expected_event_id, "%s starts expected event" % String(expected_event_id))
	assert_not_null(telegraph, "%s spawns a world-space telegraph" % String(expected_event_id))
	if telegraph != null:
		assert_eq(telegraph.encounter_id, expected_event_id, "%s telegraph keeps the mini-event id" % String(expected_event_id))
		assert_true(telegraph.high_contrast, "%s telegraph supports high contrast" % String(expected_event_id))
		visual_settings.apply_profile(&"reduced_motion")
		assert_true(telegraph.reduced_motion, "%s telegraph supports reduced motion" % String(expected_event_id))
		visual_settings.apply_profile(&"high_contrast")
	assert_not_null(_find_reward_crate(result), "%s spawns a concrete reward crate" % String(expected_event_id))
	assert_eq(int(encounter.get_debug_snapshot().get("pending_telegraph_count", 0)), 1, "%s starts a telegraph" % String(expected_event_id))
	assert_gte(int(tuning.get("threat_score", 0)), 4, "%s has meaningful threat score" % String(expected_event_id))
	match expected_event_id:
		&"toxic_leak", &"fire_breakout":
			assert_gte(int(tuning.get("hazard_count", 0)), 3, "%s scales hazards" % String(expected_event_id))
			assert_true(StringName(tuning.get("reward_crate_id", &"")) in [&"biome_toxic", &"biome_fire"], "%s uses a biome reward crate" % String(expected_event_id))
		&"whiteout":
			assert_eq(result.get("reward"), "frost_cache", "whiteout exposes frost reward")
			assert_eq(StringName(tuning.get("reward_crate_id", &"")), &"biome_frost", "whiteout uses frost crate reward")
		&"marsh_emergence":
			assert_gte(int(tuning.get("enemy_count", 0)), 3, "marsh emergence scales enemy count")
			assert_eq(StringName(tuning.get("reward_crate_id", &"")), &"biome_marsh", "marsh emergence uses marsh crate reward")
		_:
			pass

func _validate_whiteout_status_is_avoidable(
	encounter,
	hazard_system,
	far_player: Node2D,
	exposed_player: Node2D
) -> void:
	var biome = load("res://game/modes/zombie/biomes/frozen_outskirts.tres")
	assert_not_null(biome, "frozen biome loads for whiteout status")
	if biome == null:
		return
	hazard_system.start_run(biome)
	far_player.global_position = Vector2.ZERO
	var result: Dictionary = encounter.force_encounter(biome, &"whiteout", 6)
	exposed_player.global_position = result.get("position") as Vector2
	await get_tree().create_timer(0.05).timeout
	assert_false(hazard_system.has_status(far_player, &"freeze"), "whiteout does not affect players outside the telegraph")
	assert_true(hazard_system.has_status(exposed_player, &"freeze"), "whiteout affects players that remain inside the telegraph")
	hazard_system.stop_run()

# --- menu/save/audio/avvio modalità (milestone_9) ---------------------------

func test_save_and_mode_flow() -> void:
	_gameplay_feedback_events = []
	_remove_temporary_save()
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)
	var game_mode_manager = scene.node(&"game_mode_manager")
	var main_menu = scene.node(&"main_menu")
	var save_manager = scene.node(&"save_manager")
	var progression = scene.node(&"progression_manager")
	var player_manager = scene.node(&"player_manager")
	var survival_mode = scene.node(&"survival_mode")
	var dungeon_mode = scene.node(&"dungeon_mode")
	var hud = scene.node(&"hud_manager")
	var audio_manager = scene.node(&"audio_manager")
	if game_mode_manager == null or main_menu == null or save_manager == null or progression == null or player_manager == null or survival_mode == null or dungeon_mode == null or hud == null or audio_manager == null:
		assert_true(false, "menu/save systems are available")
		scene.teardown()
		return

	assert_eq(game_mode_manager.active_mode_id, MODE_MENU, "the project starts in menu state")
	assert_true(main_menu.is_open(), "the main menu is visible at startup")
	assert_false(hud.visible, "the gameplay HUD is hidden in the menu")
	assert_false(survival_mode.is_running, "survival does not auto-start behind the menu")
	assert_not_null(audio_manager.ui_player, "procedural UI audio feedback is initialized")
	assert_not_null(audio_manager.gameplay_player, "procedural gameplay audio feedback is initialized")
	audio_manager.gameplay_feedback_generated.connect(_on_gameplay_feedback_generated)
	assert_gt(audio_manager.play_gameplay_shot(&"starter_pistol"), 0, "gameplay shot feedback writes audio samples")
	assert_gt(audio_manager.play_gameplay_impact(&"starter_pistol"), 0, "gameplay impact feedback writes audio samples")
	assert_gt(audio_manager.play_gameplay_pickup(DROP_EXPERIENCE), 0, "gameplay pickup feedback writes audio samples")

	save_manager.save_path = TEMP_SAVE_PATH
	save_manager.auto_persist_in_headless = true
	progression.add_money(5)
	await wait_physics_frames(2)
	assert_true(FileAccess.file_exists(TEMP_SAVE_PATH), "progression changes trigger autosave")
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	var legacy_file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"version": 1, "party": {"level": 2, "experience": 10, "money": 20}, "settings": {"last_mode": String(MODE_SURVIVAL)}}))
	legacy_file.close()
	assert_true(save_manager.load_game(), "version 1 saves migrate through the current loader")
	assert_true(progression.has_unlock(FIELD_KIT_UNLOCK), "legacy level data grants the Field Kit unlock")
	assert_true(save_manager.save_game(), "migrated progress is written in the current format")
	assert_eq(int(_read_json_dictionary(TEMP_SAVE_PATH).get("version", 0)), SAVE_VERSION, "migrated saves use the current save version")
	progression.restore_save_data({"level": 3, "experience": 45, "money": 70, "unlocks": [String(FIELD_KIT_UNLOCK)]})
	save_manager.set_last_mode(MODE_DUNGEON)
	assert_true(save_manager.save_game(), "progression save is written")

	progression.restore_save_data({"level": 1, "experience": 0, "money": 0, "unlocks": []})
	assert_false(progression.has_unlock(FIELD_KIT_UNLOCK), "runtime progression can reset to a locked state")
	save_manager.set_last_mode(MODE_SURVIVAL)
	assert_true(save_manager.load_game(), "progression save is loaded")
	assert_eq(progression.level, 3, "save restores party level")
	assert_eq(progression.experience, 45, "save restores party experience")
	assert_eq(progression.money, 70, "save restores party money")
	assert_true(progression.has_unlock(FIELD_KIT_UNLOCK), "save restores the Field Kit unlock")
	assert_eq(save_manager.get_last_mode(), MODE_DUNGEON, "save restores the last selected mode")

	var invalid_file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	invalid_file.store_string('{"version":999,"party":{}}')
	invalid_file.close()
	assert_false(save_manager.load_game(), "unsupported save versions are rejected")
	assert_true(progression.level == 3 and progression.money == 70, "rejected saves leave runtime progression unchanged")
	assert_true(save_manager.save_game(), "valid save can replace rejected data")

	assert_true(main_menu.start_selected_mode(save_manager.get_last_mode()), "menu starts the saved mode")
	await wait_physics_frames(3)
	await wait_physics_frames(1)
	assert_eq(game_mode_manager.active_mode_id, MODE_DUNGEON, "mode selection updates the active mode")
	assert_true(dungeon_mode.is_running, "dungeon starts from the main menu")
	assert_false(main_menu.is_open(), "menu hides after mode selection")
	assert_true(hud.visible, "gameplay HUD becomes visible after mode selection")
	var player_one = player_manager.players.get(1)
	assert_not_null(player_one, "player one is available for run unlocks")
	if player_one != null:
		var player_health = player_one.get_node("HealthComponent")
		assert_true(player_health.max_health == 120 and player_health.current_health == 120, "Field Kit raises and refills player health at run start")

	main_menu.open_menu()
	await wait_physics_frames(1)
	assert_true(main_menu.is_open(), "Escape flow can return to the main menu")
	assert_false(dungeon_mode.is_running, "returning to menu stops the active mode")
	assert_eq(game_mode_manager.active_mode_id, MODE_MENU, "returning to menu restores menu state")
	assert_true(main_menu.start_selected_mode(MODE_SURVIVAL), "a second run can start after returning to the menu")
	await wait_physics_frames(2)
	if player_one != null:
		var player_health = player_one.get_node("HealthComponent")
		assert_eq(player_health.max_health, 120, "Field Kit health does not stack across runs")
		player_health.apply_damage(20)
		survival_mode.stop_mode()
		assert_true(game_mode_manager.set_mode(MODE_SURVIVAL), "the active mode can restart after stopping")
		assert_eq(player_health.current_health, 120, "same-mode restart prepares the player for a new run")
	main_menu.open_menu()
	await wait_physics_frames(1)
	assert_true(FileAccess.file_exists("res://export_presets.cfg"), "desktop export preset is present")
	assert_true(_has_gameplay_feedback(&"shot") and _has_gameplay_feedback(&"impact") and _has_gameplay_feedback(&"pickup"), "all gameplay feedback categories are emitted")

	if audio_manager.gameplay_feedback_generated.is_connected(_on_gameplay_feedback_generated):
		audio_manager.gameplay_feedback_generated.disconnect(_on_gameplay_feedback_generated)
	scene.teardown()
	await wait_physics_frames(1)
	_remove_temporary_save()

# --- helper -----------------------------------------------------------------

# Gli encounter aggiungono telegraph/crate al container risolto via
# get_tree().current_scene (RandomEncounterSystem._get_telegraph_container), che
# in headless è null: la scena sintetica va agganciata alla root e impostata come
# current_scene (come facevano i vecchi test SceneTree).
func _make_current_scene_root() -> Node2D:
	var scene_root := Node2D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	return scene_root

func _free_current_scene_root(scene_root: Node2D) -> void:
	if get_tree().current_scene == scene_root:
		get_tree().current_scene = null
	scene_root.queue_free()

func _new_main_scene_fixture():
	var script := load("res://tests/support/main_scene_fixture.gd") as Script
	assert_not_null(script, "main scene fixture script loads")
	return script.new() if script != null else null

func _new_script_node(path: String) -> Node:
	var script := load(path) as Script
	assert_not_null(script, "%s loads" % path)
	if script == null:
		return null
	var node := script.new() as Node
	assert_not_null(node, "%s instantiates a node" % path)
	return node

func _find_telegraph(result: Dictionary) -> Node:
	for entity in result.get("entities", []):
		if entity is Node and StringName(entity.get("encounter_id")) != &"":
			return entity
	return null

func _find_reward_crate(result: Dictionary) -> Node:
	for entity in result.get("entities", []):
		if entity is Node and (entity as Node).has_meta("biome_crate_id"):
			return entity
	return null

func _has_reward_crate(result: Dictionary, expected_crate_id: StringName) -> bool:
	for entity in result.get("entities", []):
		if (
			entity is Node
			and StringName((entity as Node).get_meta("biome_crate_id", &""))
			== expected_crate_id
		):
			return true
	return false

func _remove_temporary_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEMP_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _on_gameplay_feedback_generated(feedback_type: StringName, source_id: StringName, frames_written: int) -> void:
	_gameplay_feedback_events.append({"type": feedback_type, "source": source_id, "frames": frames_written})

func _has_gameplay_feedback(feedback_type: StringName) -> bool:
	for event in _gameplay_feedback_events:
		if StringName(event.get("type", &"")) == feedback_type and int(event.get("frames", 0)) > 0:
			return true
	return false
