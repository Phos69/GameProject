extends SceneTree

var failures: PackedStringArray = []
var spawned_projectiles: Array[Projectile] = []
var rejected_requests: Array[Dictionary] = []
var defeated_details: Array[Dictionary] = []
var finishing: bool = false

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

	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(boss_system != null, "boss system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(health_system != null, "health system is available")
	_expect(hud != null, "HUD manager is available")
	if (
		boss_system == null
		or player_manager == null
		or projectile_system == null
		or health_system == null
		or hud == null
	):
		_finish()
		return

	boss_system.boss_request_rejected.connect(_on_boss_request_rejected)
	boss_system.boss_defeated_detailed.connect(_on_boss_defeated_detailed)
	projectile_system.projectile_spawned.connect(_on_projectile_spawned)
	var registered_ids := boss_system.get_registered_boss_ids()
	_expect(
		registered_ids.has(&"wave_warden")
		and registered_ids.has(&"rift_architect"),
		"boss registry exposes both configured bosses"
	)
	_expect(
		boss_system.is_boss_compatible(
			&"rift_architect",
			GameConstants.MODE_DUNGEON
		),
		"Rift Architect is compatible with dungeon"
	)
	_expect(
		not boss_system.is_boss_compatible(
			&"rift_architect",
			GameConstants.MODE_TOWER_DEFENSE
		),
		"Rift Architect explicitly rejects tower defense"
	)
	var rejected_boss := boss_system.request_boss_by_id(
		&"rift_architect",
		GameConstants.MODE_TOWER_DEFENSE,
		&"compatibility_test"
	)
	_expect(rejected_boss == null, "incompatible boss request returns null")
	_expect(
		not rejected_requests.is_empty()
		and rejected_requests[-1].get("reason") == &"incompatible_mode",
		"incompatible request emits a typed rejection"
	)

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available")
	if player == null:
		_finish()
		return
	player.global_position = Vector2(280.0, 0.0)
	var warden := boss_system.request_boss_by_id(
		&"wave_warden",
		GameConstants.MODE_SURVIVAL,
		&"registry_test",
		Vector2.ZERO
	) as BasicBoss
	_expect(
		warden != null and warden.boss_id == &"wave_warden",
		"Wave Warden can still be requested by ID"
	)
	if warden == null:
		_finish()
		return
	health_system.apply_damage(warden, 99999)
	await process_frame

	var rift := boss_system.request_boss_by_id(
		&"rift_architect",
		GameConstants.MODE_DUNGEON,
		&"registry_test",
		Vector2.ZERO
	) as RiftArchitect
	_expect(rift != null, "Rift Architect spawns through the registry")
	if rift == null:
		_finish()
		return
	rift.set_physics_process(false)
	rift.target = player
	_expect(
		rift.boss_id == &"rift_architect"
		and rift.display_name == "Rift Architect",
		"second boss exposes its own identity"
	)
	_expect(
		rift.visual.get_profile_id() == &"rift_architect",
		"second boss uses a distinct modular visual"
	)
	await process_frame
	_expect(
		hud.boss_name_label.text.contains("Rift Architect"),
		"shared boss HUD displays the registered boss name"
	)

	rift.lane_telegraph_duration = 5.0
	_expect(
		rift.start_attack_telegraph(&"lane_sweep"),
		"lane sweep enters its telegraph state"
	)
	_expect(
		rift.telegraph_visual.active_pattern == &"lane_sweep",
		"lane sweep uses a distinct world-space telegraph"
	)
	_expect(
		spawned_projectiles.is_empty(),
		"lane sweep creates no projectile during warning"
	)
	_expect(
		hud.boss_warning_label.text == "LANE SWEEP - FIND THE GAP",
		"HUD explains the lane gap"
	)
	rift._finish_attack_telegraph()
	await process_frame
	_expect(
		_count_projectiles(&"rift_lane") == rift.lane_projectile_count - 1,
		"lane sweep fires every warned lane except the safe gap"
	)
	_clear_projectiles()

	var rift_health := rift.health_component
	health_system.apply_damage(
		rift,
		rift_health.current_health
		- roundi(float(rift_health.max_health) * 0.50)
	)
	_expect(rift.phase_index == 2, "Rift Architect enters phase two")
	_expect(
		rift.visual.is_phase_two_visual(),
		"phase two changes the second boss presentation"
	)
	rift.cross_telegraph_duration = 5.0
	_expect(
		rift.start_attack_telegraph(&"cross_burst"),
		"cross burst enters its telegraph state"
	)
	_expect(
		spawned_projectiles.is_empty(),
		"cross burst creates no projectile during warning"
	)
	_expect(
		hud.boss_warning_label.text == "CROSS BURST - ROTATE",
		"HUD explains the cross burst"
	)
	rift._finish_attack_telegraph()
	await process_frame
	_expect(
		_count_projectiles(&"rift_cross") == rift.cross_projectile_count,
		"cross burst fires its configured rotating cross"
	)
	_clear_projectiles()

	health_system.apply_damage(rift, 99999)
	await process_frame
	_expect(
		not defeated_details.is_empty()
		and defeated_details[-1].get("boss_id") == &"rift_architect",
		"detailed defeat event preserves boss identity"
	)
	_expect(
		_count_weapon_pickups(&"rift_repeater") >= 1,
		"Rift Architect drops its dedicated special weapon"
	)
	_finish()

func _count_projectiles(source_id: StringName) -> int:
	var count := 0
	for projectile in spawned_projectiles:
		if (
			is_instance_valid(projectile)
			and projectile.source_id == source_id
		):
			count += 1
	return count

func _clear_projectiles() -> void:
	for projectile in spawned_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	spawned_projectiles.clear()

func _count_weapon_pickups(weapon_id: StringName) -> int:
	var count := 0
	for pickup in get_nodes_in_group("drop_pickups"):
		if not pickup is DropPickup:
			continue
		if StringName(
			(pickup as DropPickup).drop_data.get("weapon_id", &"")
		) == weapon_id:
			count += 1
	return count

func _on_projectile_spawned(projectile: Node) -> void:
	if (
		projectile is Projectile
		and String(projectile.get("source_id")).begins_with("rift_")
	):
		spawned_projectiles.append(projectile as Projectile)

func _on_boss_request_rejected(
	mode_id: StringName,
	boss_id: StringName,
	reason: StringName
) -> void:
	rejected_requests.append({
		"mode_id": mode_id,
		"boss_id": boss_id,
		"reason": reason
	})

func _on_boss_defeated_detailed(
	mode_id: StringName,
	boss_id: StringName,
	display_name: String
) -> void:
	defeated_details.append({
		"mode_id": mode_id,
		"boss_id": boss_id,
		"display_name": display_name
	})

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if finishing:
		return
	finishing = true
	var exit_code := 0
	if failures.is_empty():
		print("MILESTONE_19_BOSS_REGISTRY_SMOKE_TEST: PASS")
	else:
		print(
			"MILESTONE_19_BOSS_REGISTRY_SMOKE_TEST: FAIL (%d)"
			% failures.size()
		)
		exit_code = 1
	call_deferred("_shutdown", exit_code)

func _shutdown(exit_code: int) -> void:
	for _frame in range(5):
		await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	for _frame in range(5):
		await process_frame
	quit(exit_code)
