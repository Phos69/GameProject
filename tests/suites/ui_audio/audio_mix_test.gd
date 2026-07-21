extends GutTest
## UI/Audio A9 — Mix audio: bus, fallback procedurali, cue di gameplay, persistenza.
##
## Migra:
##   tests/milestone_18_audio_mix_smoke_test.gd  (boot main.tscn, survival + cue)

const TEMP_SAVE_PATH := "user://ui_audio_audio_mix_test.json"

var _cue_events: Array[Dictionary] = []

func test_audio_mix_and_cues() -> void:
	_cue_events = []
	_remove_temporary_save()
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)

	var audio_manager: AudioManager = scene.node(&"audio_manager") as AudioManager
	var save_manager: SaveManager = scene.node(&"save_manager") as SaveManager
	var main_menu: MainMenu = scene.node(&"main_menu") as MainMenu
	var local_multiplayer: LocalMultiplayerManager = scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var enemy_system: EnemySystem = scene.node(&"enemy_system") as EnemySystem
	var revive_system = scene.node(&"revive_system")
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	assert_not_null(audio_manager, "audio manager is available")
	assert_not_null(save_manager, "save manager is available")
	assert_not_null(main_menu, "main menu is available")
	assert_not_null(local_multiplayer, "local multiplayer manager is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(enemy_system, "enemy system is available")
	assert_not_null(revive_system, "revive system is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(game_mode_manager, "game mode manager is available")
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
		scene.teardown()
		scene = null
		_remove_temporary_save()
		return

	audio_manager.cue_played.connect(_on_cue_played)
	for bus_name in AudioManager.REQUIRED_BUSES:
		assert_gte(
			AudioServer.get_bus_index(String(bus_name)), 0,
			"audio bus %s is configured" % bus_name
		)
	assert_gt(
		audio_manager.play_gameplay_shot(&"starter_pistol"), 0,
		"missing optional weapon assets use procedural fallback"
	)
	var first_pitch := float(audio_manager.last_cue_pitch.get(&"shot", 1.0))
	audio_manager.play_gameplay_shot(&"starter_pistol")
	var second_pitch := float(audio_manager.last_cue_pitch.get(&"shot", 1.0))
	assert_false(
		is_equal_approx(first_pitch, second_pitch),
		"repeated cues receive light pitch variation"
	)
	assert_true(
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
	assert_lte(
		audio_manager.voice_pool.voices.size(), 2,
		"optional SFX respect the configured voice limit"
	)
	assert_true(
		_has_optional_event(&"optional_test"),
		"optional licensed streams replace fallback when present"
	)
	assert_false(
		audio_manager.cue_registry.has(&"biome_entered"),
		"biome transitions do not register an audible notification cue"
	)

	local_multiplayer.activate_slot(2)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(2)
	assert_false(
		_has_cue_event(&"biome_entered"),
		"starting or changing biome does not emit an audible notification"
	)
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	if player_one != null and player_two != null:
		player_one.global_position = Vector2.ZERO
		player_two.global_position = Vector2(30.0, 0.0)
		player_two.health_component.apply_damage(9999)
		revive_system.set("revive_duration", 0.1)
		revive_system.call("advance_revive", player_two, player_one, 0.2)
	var shooter := enemy_system.spawn_enemy(&"survival_shooter", Vector2(200.0, 0.0))
	if shooter != null and player_one != null:
		shooter.set_physics_process(false)
		shooter.set("target", player_one)
		shooter.call("start_windup")
	wave_manager.wave_started.emit(1)
	wave_manager.wave_completed.emit(1)
	await wait_physics_frames(1)
	assert_true(
		_has_cue_event(&"player_downed") and _has_cue_event(&"player_revived"),
		"downed and revive hooks generate critical audio cues"
	)
	assert_true(
		_has_cue_event(&"enemy_telegraph"),
		"shooter windup generates its enemy cue"
	)
	assert_true(
		_has_cue_event(&"wave_start") and _has_cue_event(&"wave_clear"),
		"wave transitions generate dedicated cues"
	)

	save_manager.save_path = TEMP_SAVE_PATH
	save_manager.auto_persist_in_headless = true
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	audio_manager.set_bus_volume_linear(&"Master", 0.35)
	audio_manager.set_bus_volume_linear(&"Music", 0.55)
	audio_manager.set_bus_volume_linear(&"SFX", 0.65)
	assert_true(save_manager.save_game(), "audio settings are saved")
	audio_manager.set_bus_volume_linear(&"Master", 0.9)
	audio_manager.set_bus_volume_linear(&"Music", 0.9)
	audio_manager.set_bus_volume_linear(&"SFX", 0.9)
	assert_true(save_manager.load_game(), "audio settings are loaded")
	assert_true(
		is_equal_approx(audio_manager.get_bus_volume_linear(&"Master"), 0.35)
		and is_equal_approx(audio_manager.get_bus_volume_linear(&"Music"), 0.55)
		and is_equal_approx(audio_manager.get_bus_volume_linear(&"SFX"), 0.65),
		"master, music and SFX volumes round-trip through the current save schema"
	)
	assert_true(
		main_menu.volume_sliders.has(&"Master")
		and main_menu.volume_sliders.has(&"Music")
		and main_menu.volume_sliders.has(&"SFX"),
		"main menu exposes persistent mix controls"
	)

	if audio_manager.cue_played.is_connected(_on_cue_played):
		audio_manager.cue_played.disconnect(_on_cue_played)
	scene.teardown()
	scene = null
	await wait_physics_frames(1)
	_remove_temporary_save()

func _has_cue_event(cue_id: StringName) -> bool:
	for event in _cue_events:
		if event.get("cue_id") == cue_id:
			return true
	return false

func _has_optional_event(cue_id: StringName) -> bool:
	for event in _cue_events:
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
	_cue_events.append({
		"cue_id": cue_id,
		"bus_name": bus_name,
		"optional": used_optional_stream,
		"priority": priority,
		"frames": frames_written
	})

func _remove_temporary_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEMP_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
