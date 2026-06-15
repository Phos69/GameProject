extends SceneTree

const TEMP_SAVE_PATH: String = "user://milestone_21_visual_settings_test.json"
const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie",
	&"survival_runner",
	&"survival_tank",
	&"survival_shooter"
]

var failures: PackedStringArray = []

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
	await process_frame

	var visual_settings := get_first_node_in_group(
		"visual_settings_manager"
	) as VisualSettingsManager
	var save_manager := get_first_node_in_group(
		"save_manager"
	) as SaveManager
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var boss_system := get_first_node_in_group(
		"boss_system"
	) as BossSystem
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	var camera := main.get_node_or_null(
		"Camera2D"
	) as IsometricCameraController
	_expect(visual_settings != null, "visual settings manager is available")
	_expect(save_manager != null, "save manager is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(boss_system != null, "boss system is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(hud != null, "HUD manager is available")
	_expect(camera != null, "camera controller is available")
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
		_finish()
		return

	_expect(
		visual_settings.apply_profile(&"default"),
		"default visual profile is available"
	)
	_expect(
		visual_settings.apply_profile(&"reduced_motion"),
		"reduced motion profile is available"
	)
	_expect(
		bool(visual_settings.get_setting(&"reduced_motion"))
		and float(visual_settings.get_setting(
			&"camera_shake_intensity"
		)) == 0.0,
		"reduced motion disables shake without changing gameplay"
	)
	_expect(
		visual_settings.apply_profile(&"high_contrast"),
		"high contrast profile is available"
	)
	_expect(
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
	save_manager.save_path = TEMP_SAVE_PATH
	_remove_temp_save()
	_expect(save_manager.save_game(), "save v4 writes visual settings")
	var parsed_save := _read_temp_save()
	_expect(
		int(parsed_save.get("version", 0)) == 4,
		"visual settings bump the save schema to version 4"
	)
	var saved_settings := parsed_save.get("settings", {}) as Dictionary
	_expect(
		saved_settings.get("visual", null) is Dictionary,
		"save contains a dedicated visual settings section"
	)
	visual_settings.apply_profile(&"default")
	_expect(save_manager.load_game(), "save v4 reload succeeds")
	_expect(
		is_equal_approx(
			float(visual_settings.get_setting(&"flash_intensity")),
			0.45
		)
		and is_equal_approx(
			float(visual_settings.get_setting(&"hud_text_scale")),
			1.20
		)
		and bool(visual_settings.get_setting(&"high_contrast"))
		and bool(visual_settings.get_setting(&"reduced_motion")),
		"visual settings survive a save/load round-trip"
	)
	await process_frame
	_expect(
		hud.status_label.get_theme_font_size("font_size") == 19,
		"HUD text scale is applied at runtime"
	)

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{"arena_id": &"rift_foundry"}
	)
	await process_frame
	await process_frame
	var player_one := player_manager.players.get(1) as PlayerController
	_expect(player_one != null, "player one is available")
	if player_one == null:
		_finish()
		return
	var move_speed_before := player_one.move_speed
	var weapon_damage_before: int = int(
		player_one.weapon_system.weapon_data.damage
	)
	for slot in range(1, 5):
		var player := player_manager.players.get(slot) as PlayerController
		_expect(
			player != null
			and player.visual.player_slot == slot
			and player.visual.high_contrast,
			"player %d keeps a shape marker independent of color" % slot
		)
	_expect(
		player_one.visual.reduced_motion,
		"reduced motion reaches the player presentation"
	)

	var weapon_data := load(
		"res://game/weapons/starter_pistol.tres"
	) as WeaponData
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
	await process_frame
	_expect(projectile != null, "test projectile is available")
	if projectile != null:
		_expect(
			not projectile.glow.visible and not projectile.trail.visible,
			"zero glow and trail hide only presentation nodes"
		)
		_expect(
			projectile.damage == 17
			and is_equal_approx(projectile.velocity.length(), 120.0),
			"visual settings do not change projectile damage or speed"
		)
	visual_settings.apply_profile(&"reduced_motion")
	camera.request_shake(12.0, 0.5)
	_expect(
		camera.last_applied_shake_strength == 0.0,
		"reduced motion suppresses camera shake"
	)
	visual_settings.apply_profile(&"default")
	camera.request_shake(12.0, 0.5)
	_expect(
		camera.last_applied_shake_strength > 0.0,
		"default profile allows camera shake"
	)
	_expect(
		is_equal_approx(player_one.move_speed, move_speed_before)
		and player_one.weapon_system.weapon_data.damage
		== weapon_damage_before,
		"profile changes leave player and weapon gameplay unchanged"
	)

	var spawned_enemies: Array[Node] = []
	var arena_manager := get_first_node_in_group(
		"survival_arena_manager"
	) as SurvivalArenaManager
	var spawn_points := arena_manager.active_profile.enemy_spawn_points
	for index in range(28):
		var spawn_position := spawn_points[index % spawn_points.size()]
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()],
			spawn_position.move_toward(
				Vector2.ZERO,
				80.0 + float(index % 5) * 24.0
			)
		)
		if enemy != null:
			spawned_enemies.append(enemy)
	var boss := boss_system.request_boss_by_id(
		&"rift_architect",
		GameConstants.MODE_SURVIVAL,
		&"milestone_21_profile",
		Vector2(0.0, -170.0)
	) as RiftArchitect
	_expect(boss != null, "profiling scenario includes a boss")
	if boss != null:
		boss.target = player_one
		boss.lane_telegraph_duration = 5.0
		boss.start_attack_telegraph(&"lane_sweep")
	var profile_start := Time.get_ticks_usec()
	for _frame in range(120):
		await physics_frame
	var profile_elapsed_usec := Time.get_ticks_usec() - profile_start
	var average_frame_msec := (
		float(profile_elapsed_usec) / 1000.0 / 120.0
	)
	print(
		"PROFILE: 4 players, %d enemies, boss, 120 frames, avg %.2f ms"
		% [spawned_enemies.size(), average_frame_msec]
	)
	_expect(
		spawned_enemies.size() == 28,
		"profiling scenario contains the full mixed roster"
	)
	_expect(
		average_frame_msec < 35.0,
		"crowded profiling scenario stays within the 35 ms frame budget"
	)
	_remove_temp_save()
	_finish()

func _read_temp_save() -> Dictionary:
	var file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _remove_temp_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEMP_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_21_VISUAL_SETTINGS_PERFORMANCE_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_21_VISUAL_SETTINGS_PERFORMANCE_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
