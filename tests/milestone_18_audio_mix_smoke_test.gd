extends SceneTree

var failures: PackedStringArray = []
var cue_events: Array[Dictionary] = []
var temporary_save_path: String = "user://milestone_18_audio_test.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_temporary_save()
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
	await process_frame

	var audio_manager := get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	var save_manager := get_first_node_in_group("save_manager") as SaveManager
	var main_menu := get_first_node_in_group("main_menu") as MainMenu
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var revive_system: Node = get_first_node_in_group("revive_system")
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	_expect(audio_manager != null, "audio manager is available")
	_expect(save_manager != null, "save manager is available")
	_expect(main_menu != null, "main menu is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(revive_system != null, "revive system is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	if (
		audio_manager == null
		or save_manager == null
		or main_menu == null
		or local_multiplayer == null
		or player_manager == null
		or enemy_system == null
		or revive_system == null
		or wave_manager == null
		or game_mode_manager == null
	):
		_finish()
		return

	audio_manager.cue_played.connect(_on_cue_played)
	for bus_name in AudioManager.REQUIRED_BUSES:
		_expect(
			AudioServer.get_bus_index(String(bus_name)) >= 0,
			"audio bus %s is configured" % bus_name
		)
	_expect(
		audio_manager.play_gameplay_shot(&"starter_pistol") > 0,
		"missing optional weapon assets use procedural fallback"
	)
	var first_pitch := float(audio_manager.last_cue_pitch.get(&"shot", 1.0))
	audio_manager.play_gameplay_shot(&"starter_pistol")
	var second_pitch := float(audio_manager.last_cue_pitch.get(&"shot", 1.0))
	_expect(
		not is_equal_approx(first_pitch, second_pitch),
		"repeated cues receive light pitch variation"
	)
	_expect(
		audio_manager._shot_frequency(&"starter_pistol")
		!= audio_manager._shot_frequency(&"prototype_blaster")
		and audio_manager._shot_frequency(&"prototype_blaster")
		!= audio_manager._shot_frequency(&"wave_cannon"),
		"the three player weapons use distinct fallback SFX"
	)

	var optional_cue := AudioCueData.new()
	optional_cue.cue_id = &"optional_test"
	optional_cue.bus_name = &"Environment"
	optional_cue.priority = 10
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.data = PackedByteArray([128, 150, 170, 150, 128, 106, 86, 106])
	optional_cue.optional_stream = stream
	audio_manager.cue_registry[optional_cue.cue_id] = optional_cue
	audio_manager.voice_pool.max_voices = 2
	audio_manager.play_cue(&"optional_test")
	audio_manager.play_cue(&"optional_test")
	audio_manager.play_cue(&"optional_test")
	_expect(
		audio_manager.voice_pool.voices.size() <= 2,
		"optional SFX respect the configured voice limit"
	)
	_expect(
		_has_optional_event(&"optional_test"),
		"optional licensed streams replace fallback when present"
	)

	local_multiplayer.activate_slot(2)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	await process_frame
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	if player_one != null and player_two != null:
		player_one.global_position = Vector2.ZERO
		player_two.global_position = Vector2(30.0, 0.0)
		player_two.health_component.apply_damage(9999)
		revive_system.set("revive_duration", 0.1)
		revive_system.call(
			"advance_revive",
			player_two,
			player_one,
			0.2
		)
	var shooter: Node = enemy_system.spawn_enemy(
		&"survival_shooter",
		Vector2(200.0, 0.0)
	)
	if shooter != null and player_one != null:
		shooter.set_physics_process(false)
		shooter.set("target", player_one)
		shooter.call("start_windup")
	wave_manager.wave_started.emit(1)
	wave_manager.wave_completed.emit(1)
	await process_frame
	_expect(
		_has_cue_event(&"player_downed")
		and _has_cue_event(&"player_revived"),
		"downed and revive hooks generate critical audio cues"
	)
	_expect(
		_has_cue_event(&"enemy_telegraph"),
		"shooter windup generates its enemy cue"
	)
	_expect(
		_has_cue_event(&"wave_start") and _has_cue_event(&"wave_clear"),
		"wave transitions generate dedicated cues"
	)

	save_manager.save_path = temporary_save_path
	save_manager.auto_persist_in_headless = true
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	audio_manager.set_bus_volume_linear(&"Master", 0.35)
	audio_manager.set_bus_volume_linear(&"Music", 0.55)
	audio_manager.set_bus_volume_linear(&"SFX", 0.65)
	_expect(save_manager.save_game(), "audio settings are saved")
	audio_manager.set_bus_volume_linear(&"Master", 0.9)
	audio_manager.set_bus_volume_linear(&"Music", 0.9)
	audio_manager.set_bus_volume_linear(&"SFX", 0.9)
	_expect(save_manager.load_game(), "audio settings are loaded")
	_expect(
		is_equal_approx(
			audio_manager.get_bus_volume_linear(&"Master"),
			0.35
		)
		and is_equal_approx(
			audio_manager.get_bus_volume_linear(&"Music"),
			0.55
		)
		and is_equal_approx(
			audio_manager.get_bus_volume_linear(&"SFX"),
			0.65
		),
		"master, music and SFX volumes round-trip through save v4"
	)
	_expect(
		main_menu.volume_sliders.has(&"Master")
		and main_menu.volume_sliders.has(&"Music")
		and main_menu.volume_sliders.has(&"SFX"),
		"main menu exposes persistent mix controls"
	)

	_finish()

func _has_cue_event(cue_id: StringName) -> bool:
	for event in cue_events:
		if event.get("cue_id") == cue_id:
			return true
	return false

func _has_optional_event(cue_id: StringName) -> bool:
	for event in cue_events:
		if event.get("cue_id") == cue_id and bool(event.get("optional", false)):
			return true
	return false

func _on_cue_played(
	cue_id: StringName,
	bus_name: StringName,
	used_optional_stream: bool,
	priority: int,
	frames_written: int
) -> void:
	cue_events.append({
		"cue_id": cue_id,
		"bus_name": bus_name,
		"optional": used_optional_stream,
		"priority": priority,
		"frames": frames_written
	})

func _remove_temporary_save() -> void:
	if FileAccess.file_exists(temporary_save_path):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(temporary_save_path)
		)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	_remove_temporary_save()
	if failures.is_empty():
		print("MILESTONE_18_AUDIO_MIX_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_18_AUDIO_MIX_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
