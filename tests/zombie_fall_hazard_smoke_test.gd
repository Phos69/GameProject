extends SceneTree

var failures: PackedStringArray = []
var cue_ids: Array[StringName] = []

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

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var hazard_system := get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	var zombie_spawner := get_first_node_in_group(
		"zombie_spawner"
	) as ZombieSpawner
	var gameplay_effects := get_first_node_in_group(
		"gameplay_effects"
	) as GameplayEffects
	var audio_manager := get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	var player := get_first_node_in_group("players") as PlayerController
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(hazard_system != null, "hazard system is available")
	_expect(zombie_spawner != null, "zombie spawner is available")
	_expect(gameplay_effects != null, "gameplay effects are available")
	_expect(audio_manager != null, "audio manager is available")
	_expect(player != null, "player one is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or hazard_system == null
		or zombie_spawner == null
		or gameplay_effects == null
		or audio_manager == null
		or player == null
	):
		_finish()
		return

	audio_manager.cue_played.connect(_on_cue_played)
	wave_manager.initial_delay = 100.0
	hazard_system.safe_position_update_interval = 0.05
	hazard_system.fall_respawn_invulnerability = 0.20
	hazard_system.fall_retrigger_cooldown = 0.15
	_expect(
		hazard_system.fall_damage == 20,
		"fall damage defaults to exactly 20 HP"
	)
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
		"survival starts with fall hazards enabled"
	)
	await process_frame
	await process_frame
	await physics_frame

	var hazards := hazard_system.get_active_hazards()
	_expect(hazards.size() == 1, "starting biome creates one fall zone")
	if hazards.is_empty():
		_finish()
		return
	var fall_zone := hazards[0] as BiomeFallZone
	_expect(fall_zone != null, "generated hazard uses BiomeFallZone")
	if fall_zone == null:
		_finish()
		return
	_expect(
		fall_zone.is_in_group("fall_zones")
		and fall_zone.is_in_group("environment_hazards"),
		"fall zone is registered for hazard and spawn validation"
	)
	_expect(
		hazard_system.is_position_hazardous(fall_zone.global_position),
		"fall zone center is reported as hazardous"
	)
	_expect(
		not zombie_spawner.is_spawn_position_valid(
			fall_zone.global_position
		),
		"zombie spawner rejects the fall zone"
	)

	var safe_position := Vector2(120.0, 0.0)
	player.global_position = safe_position
	player.velocity = Vector2(80.0, 0.0)
	for _frame in range(8):
		await physics_frame
	var recorded_safe_position := hazard_system.get_last_safe_position(player)
	_expect(
		recorded_safe_position.distance_to(safe_position) < 2.0,
		"safe-position tracker records a valid player location"
	)
	_expect(
		not hazard_system.is_position_safe(
			fall_zone.global_position
			+ Vector2(fall_zone.zone_size.x * 0.5 + 12.0, 0.0)
		),
		"safe positions require clearance from the fall zone"
	)

	var health := player.health_component
	var health_before := health.current_health
	var external_source := &"test_external_invulnerability"
	var fall_source := StringName(
		"fall_respawn_%d" % player.get_instance_id()
	)
	health.add_invulnerability_source(external_source)
	var effect_count_before := gameplay_effects.effect_spawn_count
	player.global_position = fall_zone.global_position
	for _frame in range(30):
		await physics_frame
		if health.current_health < health_before:
			break

	_expect(
		health.current_health == health_before - 20,
		"fall applies exactly 20 HP even during another invulnerability"
	)
	_expect(
		player.global_position.distance_to(recorded_safe_position) < 2.0,
		"player respawns at the last safe position"
	)
	_expect(
		player.velocity.is_zero_approx(),
		"respawn clears player velocity"
	)
	_expect(
		health.has_invulnerability_source(fall_source),
		"fall grants a dedicated temporary invulnerability source"
	)
	_expect(
		health.has_invulnerability_source(external_source),
		"fall does not replace an existing invulnerability source"
	)
	_expect(
		gameplay_effects.effect_spawn_count >= effect_count_before + 2
		and _has_effect_kind(gameplay_effects, &"fall_damage")
		and _has_effect_kind(gameplay_effects, &"fall_respawn"),
		"fall generates damage and respawn visual feedback"
	)
	_expect(
		cue_ids.has(&"player_fell"),
		"fall generates its environment audio cue"
	)
	_expect(
		not hazard_system.trigger_fall(player, fall_zone),
		"fall cooldown prevents an immediate duplicate trigger"
	)

	for _frame in range(24):
		await physics_frame
	_expect(
		not health.has_invulnerability_source(fall_source),
		"fall invulnerability expires after the configured duration"
	)
	_expect(
		health.has_invulnerability_source(external_source)
		and health.is_invulnerable(),
		"other invulnerability remains active after fall recovery"
	)
	health.remove_invulnerability_source(external_source)
	_expect(
		not health.is_invulnerable(),
		"player becomes vulnerable when all sources are removed"
	)

	survival_mode.stop_mode()
	await process_frame
	await process_frame
	_expect(
		hazard_system.get_active_hazards().is_empty(),
		"fall zones are removed when survival stops"
	)
	_expect(
		not health.has_invulnerability_source(fall_source),
		"stopping survival leaves no fall invulnerability token"
	)
	_finish()

func _has_effect_kind(
	gameplay_effects: GameplayEffects,
	effect_kind: StringName
) -> bool:
	for effect in gameplay_effects.get_children():
		if effect is GameplayEffect and effect.effect_kind == effect_kind:
			return true
	return false

func _on_cue_played(
	cue_id: StringName,
	_bus_name: StringName,
	_used_optional_stream: bool,
	_priority: int,
	_frames_written: int
) -> void:
	cue_ids.append(cue_id)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_FALL_HAZARD_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_FALL_HAZARD_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
