extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"
const VISUAL_QA_RUNTIME = preload(
	"res://tests/visual_qa/helpers/visual_qa_runtime.gd"
)

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for revive QA")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var revive_system: Node = get_first_node_in_group("revive_system")
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(revive_system != null, "revive system is available")
	_expect(wave_manager != null, "wave manager is available")
	if (
		game_mode_manager == null
		or local_multiplayer == null
		or player_manager == null
		or revive_system == null
		or wave_manager == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var world_ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL
				and player_manager.players.size() == 4
			)
	)
	_expect(
		bool(world_ready.get("ready", false)),
		"revive world is capture-ready: %s"
		% VISUAL_QA_RUNTIME.describe_failure(world_ready)
	)

	var positions := [
		Vector2(-145.0, 25.0),
		Vector2(-80.0, 25.0),
		Vector2(80.0, 25.0),
		Vector2(155.0, 25.0)
	]
	for player_slot in range(1, 5):
		var player := player_manager.players.get(player_slot) as PlayerController
		if player != null:
			player.global_position = positions[player_slot - 1]

	var downed_player := player_manager.players.get(2) as PlayerController
	var reviver := player_manager.players.get(1) as PlayerController
	_expect(
		downed_player != null and reviver != null,
		"downed target and reviver are available"
	)
	if downed_player != null and reviver != null:
		revive_system.set_physics_process(false)
		downed_player.health_component.apply_damage(9999)
		revive_system.set("revive_duration", 4.0)
		revive_system.call(
			"advance_revive",
			downed_player,
			reviver,
			2.4
		)

	await process_frame
	await process_frame
	_expect(
		downed_player != null
		and downed_player.is_downed()
		and float(revive_system.call("get_revive_progress", downed_player)) > 0.5,
		"downed/revive progress marker is active"
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("milestone_16_downed_revive.png"),
		"downed and revive screenshot is captured"
	)
	_finish()

func _capture(file_name: String) -> bool:
	await process_frame
	if VISUAL_QA_RUNTIME.has_loading_overlay(self):
		return false
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	var exit_code := 0
	if failures.is_empty():
		print("DOWNED_REVIVE_VISUAL_QA: PASS")
	else:
		exit_code = 1
		print("DOWNED_REVIVE_VISUAL_QA: FAIL (%d)" % failures.size())
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
