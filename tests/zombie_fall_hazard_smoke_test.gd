extends SceneTree

var failures: PackedStringArray = []
var cue_ids: Array[StringName] = []
var finish_requested: bool = false
var spawned_drop_count: int = 0
var void_enemy_death_reason: StringName = &""

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
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var drop_system := get_first_node_in_group("drop_system") as DropSystem
	var health_system := get_first_node_in_group("health_system") as HealthSystem
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
	_expect(enemy_system != null, "enemy system is available")
	_expect(drop_system != null, "drop system is available")
	_expect(health_system != null, "health system is available")
	_expect(gameplay_effects != null, "gameplay effects are available")
	_expect(audio_manager != null, "audio manager is available")
	_expect(player != null, "player one is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or hazard_system == null
		or zombie_spawner == null
		or enemy_system == null
		or drop_system == null
		or health_system == null
		or gameplay_effects == null
		or audio_manager == null
		or player == null
	):
		_finish()
		return

	audio_manager.cue_played.connect(_on_cue_played)
	drop_system.drop_spawned.connect(_on_drop_spawned)
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
	_expect(hazards.size() >= 1, "starting biome creates fall zone coverage")
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
		hazard_system.is_position_fall_zone(fall_zone.global_position),
		"fall zone center is reported by the dedicated fall query"
	)
	_expect(
		not hazard_system.is_position_environment_hazard(
			fall_zone.global_position
		),
		"fall zone is not reported as a generic environment hazard"
	)
	_expect(
		fall_zone.get_fall_style() == &"cliff",
		"starting biome fall zone uses the default cliff visual style"
	)
	var runtime_environment_hazard := hazard_system.spawn_runtime_hazard(
		&"fire_zone",
		Vector2(520.0, 0.0)
	)
	_expect(
		runtime_environment_hazard != null,
		"runtime environmental hazard can be spawned for query checks"
	)
	if runtime_environment_hazard != null:
		await process_frame
		_expect(
			hazard_system.is_position_environment_hazard(
				runtime_environment_hazard.global_position
			),
			"environmental hazard is reported by the environment query"
		)
		_expect(
			not hazard_system.is_position_fall_zone(
				runtime_environment_hazard.global_position
			),
			"environmental hazard is not reported as a fall zone"
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

	var health_before_void_dodge := health.current_health
	_start_test_dodge(
		player,
		fall_zone.global_position,
		fall_zone.global_position,
		0.18
	)
	for _frame in range(4):
		await physics_frame
	_expect(
		player.get_entity_state_name() == &"dodging"
		and health.current_health == health_before_void_dodge,
		"void does not damage or interrupt an active dodge"
	)
	for _frame in range(18):
		await physics_frame
		if player.get_entity_state_name() == &"falling":
			break
	_expect(
		player.get_entity_state_name() == &"falling"
		and health.current_health == health_before_void_dodge,
		"dodge landing on void starts falling before damage"
	)
	for _frame in range(40):
		await physics_frame
		if health.current_health < health_before_void_dodge:
			break
	_expect(
		health.current_health == health_before_void_dodge - 20
		and player.global_position.distance_to(recorded_safe_position) < 2.0,
		"void dodge landing applies one fall hit and respawns safely"
	)

	var health_before_safe_dodge := health.current_health
	_start_test_dodge(
		player,
		recorded_safe_position,
		recorded_safe_position + Vector2(8.0, 0.0),
		0.12
	)
	for _frame in range(16):
		await physics_frame
	_expect(
		player.get_entity_state_name() == &"normal"
		and health.current_health == health_before_safe_dodge,
		"dodge landing on walkable terrain returns to normal without damage"
	)

	var guaranteed_entry := DropEntry.new()
	guaranteed_entry.drop_type = GameConstants.DROP_MONEY
	guaranteed_entry.chance = 1.0
	guaranteed_entry.min_amount = 10
	guaranteed_entry.max_amount = 10
	var guaranteed_loot := LootTable.new()
	guaranteed_loot.entries.append(guaranteed_entry)
	var enemy := enemy_system.spawn_enemy(
		&"basic_zombie",
		recorded_safe_position + Vector2(32.0, 0.0)
	) as BasicEnemy
	_expect(enemy != null, "test zombie spawns for void-death validation")
	if enemy != null:
		enemy.loot_table = guaranteed_loot
		enemy.kill_experience = 23
		enemy.died.connect(_on_test_enemy_died)
		health_system.apply_damage(enemy, 1, player, &"test_player_damage")
		var experience_before := player.rpg_component.experience
		var drops_before := spawned_drop_count
		enemy.global_position = fall_zone.global_position
		for _frame in range(5):
			await physics_frame
			if enemy.get_state_name() == &"falling":
				break
		_expect(
			enemy.get_state_name() == &"falling"
			and enemy.health_component.is_alive(),
			"zombie enters falling state and stays alive during animation"
		)
		for _frame in range(45):
			await physics_frame
			if not is_instance_valid(enemy):
				break
		await process_frame
		_expect(
			void_enemy_death_reason == &"void",
			"zombie void death exposes an explicit death reason"
		)
		_expect(
			spawned_drop_count == drops_before,
			"zombie void death does not spawn guaranteed loot"
		)
		_expect(
			player.rpg_component.experience == experience_before,
			"zombie void death grants no kill experience"
		)
	for _frame in range(12):
		await process_frame

	if audio_manager.cue_played.is_connected(_on_cue_played):
		audio_manager.cue_played.disconnect(_on_cue_played)
	if drop_system.drop_spawned.is_connected(_on_drop_spawned):
		drop_system.drop_spawned.disconnect(_on_drop_spawned)
	game_mode_manager.set_mode(GameConstants.MODE_MENU)
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

func _on_drop_spawned(_pickup: Node, _drop_data: Dictionary) -> void:
	spawned_drop_count += 1

func _on_test_enemy_died(enemy: Node) -> void:
	if enemy != null and enemy.has_method("get_death_reason"):
		void_enemy_death_reason = StringName(enemy.call("get_death_reason"))

func _start_test_dodge(
	player: PlayerController,
	start: Vector2,
	target: Vector2,
	duration: float
) -> void:
	var component := player.dodge_component
	component.reset_runtime()
	player.global_position = start
	component.start_position = start
	component.target_position = target
	component.dodge_direction = start.direction_to(target)
	if component.dodge_direction.is_zero_approx():
		component.dodge_direction = Vector2.RIGHT
	component.dodge_duration = duration
	component.dodge_time_left = duration
	component.is_dodging = true
	component.dodge_started.emit(
		component.dodge_direction,
		target,
		start != target
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if finish_requested:
		return
	finish_requested = true
	call_deferred("_finish_after_teardown")

func _finish_after_teardown() -> void:
	for _frame in range(5):
		await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	for _frame in range(5):
		await process_frame
	if failures.is_empty():
		print("ZOMBIE_FALL_HAZARD_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_FALL_HAZARD_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
