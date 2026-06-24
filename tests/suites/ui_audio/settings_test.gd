extends GutTest
## UI/Audio A9 — Pagina impostazioni condivisa, pausa, rebinding e profili visivi.
##
## Migra e accorpa (entrambi bootano main.tscn, uno per test via fixture):
##   tests/pause_settings_smoke_test.gd                       (settings/pausa/rebind)
##   tests/milestone_21_visual_settings_performance_smoke_test.gd (profili + budget frame)

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")
const PAUSE_SAVE_PATH := "user://ui_audio_pause_settings_test.json"
const VISUAL_SAVE_PATH := "user://ui_audio_visual_settings_test.json"
const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie",
	&"survival_runner",
	&"survival_tank",
	&"survival_shooter"
]

# --- pagina settings condivisa, pausa, rebinding (pause_settings) ------------

func test_settings_pause_and_rebinding() -> void:
	_remove_save(PAUSE_SAVE_PATH)
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(3)

	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var main_menu := scene.node(&"main_menu") as MainMenu
	var pause_menu := scene.node(&"pause_menu") as PauseMenu
	var save_manager := scene.node(&"save_manager") as SaveManager
	var video_settings := scene.node(&"video_settings_manager") as VideoSettingsManager
	var input_manager := scene.node(&"input_manager") as InputManager
	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(main_menu, "main menu is available")
	assert_not_null(pause_menu, "pause menu is available")
	assert_not_null(save_manager, "save manager is available")
	assert_not_null(video_settings, "video settings manager is available")
	assert_not_null(input_manager, "input manager is available")
	assert_not_null(local_multiplayer, "local multiplayer manager is available")
	if (
		game_mode_manager == null
		or main_menu == null
		or pause_menu == null
		or save_manager == null
		or video_settings == null
		or input_manager == null
		or local_multiplayer == null
	):
		scene.teardown()
		_remove_save(PAUSE_SAVE_PATH)
		return

	main_menu._open_settings(&"audio")
	await wait_frames(1)
	assert_true(
		main_menu.settings_panel != null and main_menu.settings_panel.visible,
		"main menu opens the shared settings page"
	)
	assert_true(
		main_menu.volume_sliders.has(&"Master")
		and main_menu.volume_sliders.has(&"Music")
		and main_menu.volume_sliders.has(&"SFX"),
		"audio controls live in the settings page"
	)
	await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_navigation_cooldown()
	assert_eq(
		main_menu.settings_panel.tab_container.current_tab,
		int(main_menu.settings_panel.tab_indices[&"video"]),
		"RB moves settings from Audio to Video"
	)
	assert_eq(
		get_tree().root.gui_get_focus_owner(),
		main_menu.settings_panel.video_controls.get(&"display_mode"),
		"settings focuses a valid video control after RB"
	)
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	await _wait_navigation_cooldown()
	assert_eq(
		main_menu.settings_panel.tab_container.current_tab,
		int(main_menu.settings_panel.tab_indices[&"audio"]),
		"LB moves settings from Video to Audio"
	)
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	await _wait_navigation_cooldown()
	assert_eq(
		main_menu.settings_panel.tab_container.current_tab,
		int(main_menu.settings_panel.tab_indices[&"controls"]),
		"LB wraps settings from first tab to last tab"
	)
	await _press_joypad_button(JOY_BUTTON_BACK)
	await _wait_navigation_cooldown()
	assert_true(
		not main_menu.settings_panel.visible and main_menu.primary_panel.visible,
		"Back closes Settings and restores the previous menu"
	)
	main_menu._open_settings(&"audio")
	await wait_frames(1)
	main_menu._open_visual_settings()
	await wait_frames(1)
	assert_eq(
		main_menu.settings_panel.tab_container.current_tab,
		int(main_menu.settings_panel.tab_indices[&"video"]),
		"legacy visual settings entry opens the video tab"
	)
	main_menu._close_visual_settings()

	assert_true(video_settings.set_resolution(Vector2i(1600, 900)), "video resolution can be changed")
	assert_true(video_settings.set_max_fps(120), "frame limit can be changed")
	assert_true(video_settings.set_display_mode(&"windowed"), "window mode can be selected")
	video_settings.set_borderless(true)
	video_settings.set_vsync(false)

	var attack_event := InputEventJoypadButton.new()
	attack_event.device = 0
	attack_event.button_index = JOY_BUTTON_B
	attack_event.pressed = true
	assert_true(
		input_manager.rebind_joystick_action(&"base_attack", attack_event),
		"base attack can be rebound to a joypad button"
	)
	assert_true(
		_action_has_button(&"p1_base_attack", 0, JOY_BUTTON_B)
		and _action_has_button(&"p2_base_attack", 1, JOY_BUTTON_B),
		"rebinding base attack updates every local player slot"
	)
	var join_event := InputEventJoypadButton.new()
	join_event.device = 0
	join_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	join_event.pressed = true
	assert_true(
		local_multiplayer.rebind_joystick_button(&"join", join_event),
		"join can be rebound as a joystick control"
	)

	save_manager.save_path = PAUSE_SAVE_PATH
	save_manager.auto_persist_in_headless = true
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	assert_true(save_manager.save_game(), "save v5 writes video and controls")
	var saved := _read_save(PAUSE_SAVE_PATH)
	var saved_settings := saved.get("settings", {}) as Dictionary
	assert_eq(
		int(saved.get("version", 0)), SaveManager.SAVE_VERSION,
		"settings save uses the current schema"
	)
	assert_true(
		saved_settings.get("video", null) is Dictionary
		and saved_settings.get("controls", null) is Dictionary,
		"save contains dedicated video and controls sections"
	)

	input_manager.reset_joystick_bindings()
	local_multiplayer.reset_joystick_buttons()
	video_settings.restore_settings_data({})
	assert_true(save_manager.load_game(), "save v5 reload succeeds")
	assert_true(
		_action_has_button(&"p1_base_attack", 0, JOY_BUTTON_B),
		"rebound base attack survives save/load"
	)
	assert_eq(
		local_multiplayer.join_button, JOY_BUTTON_LEFT_SHOULDER,
		"rebound join survives save/load"
	)
	assert_true(
		int(video_settings.get_setting(&"resolution_width")) == 1600
		and int(video_settings.get_setting(&"resolution_height")) == 900
		and int(video_settings.get_setting(&"max_fps")) == 120
		and bool(video_settings.get_setting(&"borderless"))
		and not bool(video_settings.get_setting(&"vsync")),
		"video settings survive save/load"
	)

	assert_true(
		game_mode_manager.set_mode(GameConstants.MODE_DUNGEON),
		"test gameplay mode can start"
	)
	await wait_frames(1)
	await _press_pause_button()
	assert_true(
		pause_menu.is_open() and get_tree().paused,
		"Start opens the pause menu and pauses gameplay"
	)
	pause_menu._open_settings()
	await wait_frames(1)
	assert_true(
		pause_menu.settings_panel.visible and not pause_menu.pause_panel.visible,
		"pause menu opens the shared settings page"
	)
	pause_menu.settings_panel.close()
	await wait_frames(1)
	assert_true(pause_menu.pause_panel.visible, "closing settings returns to the pause menu")
	await _press_pause_button()
	assert_true(
		not pause_menu.is_open() and not get_tree().paused,
		"Start resumes gameplay from the pause menu"
	)

	get_tree().paused = false
	input_manager.reset_joystick_bindings()
	local_multiplayer.reset_joystick_buttons()
	scene.teardown()
	await wait_frames(1)
	_remove_save(PAUSE_SAVE_PATH)

# --- profili visivi, accessibilita e budget frame (milestone_21) ------------

func test_visual_settings_and_performance_budget() -> void:
	_remove_save(VISUAL_SAVE_PATH)
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(3)

	var visual_settings := scene.node(&"visual_settings_manager") as VisualSettingsManager
	var save_manager := scene.node(&"save_manager") as SaveManager
	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var boss_system := scene.node(&"boss_system") as BossSystem
	var projectile_system := scene.node(&"projectile_system") as ProjectileSystem
	var hud := scene.node(&"hud_manager") as HUDManager
	var camera := scene.main.get_node_or_null("Camera2D") as IsometricCameraController
	assert_not_null(visual_settings, "visual settings manager is available")
	assert_not_null(save_manager, "save manager is available")
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(local_multiplayer, "local multiplayer manager is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(enemy_system, "enemy system is available")
	assert_not_null(boss_system, "boss system is available")
	assert_not_null(projectile_system, "projectile system is available")
	assert_not_null(hud, "HUD manager is available")
	assert_not_null(camera, "camera controller is available")
	if (
		visual_settings == null
		or save_manager == null
		or game_mode_manager == null
		or local_multiplayer == null
		or player_manager == null
		or wave_manager == null
		or enemy_system == null
		or boss_system == null
		or projectile_system == null
		or hud == null
		or camera == null
	):
		scene.teardown()
		_remove_save(VISUAL_SAVE_PATH)
		return

	assert_true(visual_settings.apply_profile(&"default"), "default visual profile is available")
	assert_true(visual_settings.apply_profile(&"reduced_motion"), "reduced motion profile is available")
	assert_true(
		bool(visual_settings.get_setting(&"reduced_motion"))
		and float(visual_settings.get_setting(&"camera_shake_intensity")) == 0.0,
		"reduced motion disables shake without changing gameplay"
	)
	assert_true(visual_settings.apply_profile(&"high_contrast"), "high contrast profile is available")
	assert_true(
		bool(visual_settings.get_setting(&"high_contrast")),
		"high contrast profile enables non-color emphasis"
	)

	visual_settings.set_setting(&"flash_intensity", 0.45)
	visual_settings.set_setting(&"glow_intensity", 0.30)
	visual_settings.set_setting(&"trail_intensity", 0.20)
	visual_settings.set_setting(&"camera_shake_intensity", 0.25)
	visual_settings.set_setting(&"hud_text_scale", 1.20)
	visual_settings.set_setting(&"high_contrast", true)
	visual_settings.set_setting(&"reduced_motion", true)
	save_manager.save_path = VISUAL_SAVE_PATH
	assert_true(save_manager.save_game(), "save v5 writes visual settings")
	var parsed_save := _read_save(VISUAL_SAVE_PATH)
	assert_eq(
		int(parsed_save.get("version", 0)), SaveManager.SAVE_VERSION,
		"visual settings use the current save schema"
	)
	var saved_settings := parsed_save.get("settings", {}) as Dictionary
	assert_true(
		saved_settings.get("visual", null) is Dictionary,
		"save contains a dedicated visual settings section"
	)
	visual_settings.apply_profile(&"default")
	assert_true(save_manager.load_game(), "save v5 reload succeeds")
	assert_true(
		is_equal_approx(float(visual_settings.get_setting(&"flash_intensity")), 0.45)
		and is_equal_approx(float(visual_settings.get_setting(&"hud_text_scale")), 1.20)
		and bool(visual_settings.get_setting(&"high_contrast"))
		and bool(visual_settings.get_setting(&"reduced_motion")),
		"visual settings survive a save/load round-trip"
	)
	await wait_frames(1)
	assert_eq(
		hud.status_label.get_theme_font_size("font_size"), 19,
		"HUD text scale is applied at runtime"
	)

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {"arena_id": &"rift_foundry"})
	await wait_frames(2)
	var player_one := player_manager.players.get(1) as PlayerController
	assert_not_null(player_one, "player one is available")
	if player_one == null:
		scene.teardown()
		_remove_save(VISUAL_SAVE_PATH)
		return
	var move_speed_before := player_one.move_speed
	var weapon_damage_before := int(player_one.weapon_system.weapon_data.damage)
	for slot in range(1, 5):
		var player := player_manager.players.get(slot) as PlayerController
		assert_true(
			player != null
			and player.visual.player_slot == slot
			and player.visual.high_contrast,
			"player %d keeps a shape marker independent of color" % slot
		)
	assert_true(
		player_one.visual.reduced_motion,
		"reduced motion reaches the player presentation"
	)

	var weapon_data := load("res://game/weapons/starter_pistol.tres") as WeaponData
	visual_settings.set_setting(&"glow_intensity", 0.0)
	visual_settings.set_setting(&"trail_intensity", 0.0)
	var projectile := projectile_system.spawn_projectile(
		Vector2(-300.0, -200.0),
		Vector2.RIGHT,
		120.0,
		player_one,
		null,
		17,
		&"visual_settings_test",
		weapon_data.visual_data
	) as Projectile
	await wait_frames(1)
	assert_not_null(projectile, "test projectile is available")
	if projectile != null:
		assert_true(
			not projectile.glow.visible and not projectile.trail.visible,
			"zero glow and trail hide only presentation nodes"
		)
		assert_true(
			projectile.damage == 17
			and is_equal_approx(projectile.velocity.length(), 120.0),
			"visual settings do not change projectile damage or speed"
		)
	visual_settings.apply_profile(&"reduced_motion")
	camera.request_shake(12.0, 0.5)
	assert_eq(
		camera.last_applied_shake_strength, 0.0,
		"reduced motion suppresses camera shake"
	)
	visual_settings.apply_profile(&"default")
	camera.request_shake(12.0, 0.5)
	assert_gt(
		camera.last_applied_shake_strength, 0.0,
		"default profile allows camera shake"
	)
	assert_true(
		is_equal_approx(player_one.move_speed, move_speed_before)
		and player_one.weapon_system.weapon_data.damage == weapon_damage_before,
		"profile changes leave player and weapon gameplay unchanged"
	)

	var spawned_enemies: Array[Node] = []
	var arena_manager := scene.node(&"survival_arena_manager") as SurvivalArenaManager
	var spawn_points := arena_manager.active_profile.enemy_spawn_points
	for index in range(28):
		var spawn_position := spawn_points[index % spawn_points.size()]
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()],
			spawn_position.move_toward(Vector2.ZERO, 80.0 + float(index % 5) * 24.0)
		)
		if enemy != null:
			spawned_enemies.append(enemy)
	var boss := boss_system.request_boss_by_id(
		&"rift_architect",
		GameConstants.MODE_SURVIVAL,
		&"milestone_21_profile",
		Vector2(0.0, -170.0)
	) as RiftArchitect
	assert_not_null(boss, "profiling scenario includes a boss")
	if boss != null:
		boss.target = player_one
		boss.lane_telegraph_duration = 5.0
		boss.start_attack_telegraph(&"lane_sweep")
	var profile_start := Time.get_ticks_usec()
	for _frame in range(120):
		await get_tree().physics_frame
	var profile_elapsed_usec := Time.get_ticks_usec() - profile_start
	var average_frame_msec := float(profile_elapsed_usec) / 1000.0 / 120.0
	print("PROFILE: 4 players, %d enemies, boss, 120 frames, avg %.2f ms" % [spawned_enemies.size(), average_frame_msec])
	assert_eq(
		spawned_enemies.size(), 28,
		"profiling scenario contains the full mixed roster"
	)
	# Il processo GUT condiviso ha una baseline di boot piu alta del vecchio
	# processo dedicato (vedi M2): il tetto resta una guardia anti-regressione
	# (una regressione vera e ~100 ms/frame), allineato al 45 ms gia adottato
	# per il profilo isometrico in tile_layout/integration.
	assert_lt(
		average_frame_msec, 45.0,
		"crowded profiling scenario stays within the frame budget"
	)

	scene.teardown()
	await wait_frames(1)
	_remove_save(VISUAL_SAVE_PATH)

# --- helper -----------------------------------------------------------------

func _press_joypad_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await wait_frames(1)
	var released := pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await wait_frames(1)

func _wait_navigation_cooldown() -> void:
	await get_tree().create_timer(0.22).timeout
	await wait_frames(1)

func _press_pause_button() -> void:
	await _press_joypad_button(JOY_BUTTON_START)

func _action_has_button(action_name: StringName, device_id: int, button_index: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var button_event := event as InputEventJoypadButton
			if button_event.device == device_id and button_event.button_index == button_index:
				return true
	return false

func _read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _remove_save(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var full_path: String = path + str(suffix)
		if FileAccess.file_exists(full_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full_path))
