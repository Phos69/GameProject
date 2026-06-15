extends Node
class_name AudioEventRouter

var audio_manager: AudioManager

func _ready() -> void:
	call_deferred("_connect_sources")

func _connect_sources() -> void:
	if audio_manager == null:
		return
	var projectile_system := get_tree().get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	if projectile_system != null:
		var spawn_callback := Callable(self, "_on_projectile_spawned")
		if not projectile_system.projectile_spawned.is_connected(spawn_callback):
			projectile_system.projectile_spawned.connect(spawn_callback)
		var impact_callback := Callable(self, "_on_projectile_impacted")
		if not projectile_system.projectile_impacted.is_connected(impact_callback):
			projectile_system.projectile_impacted.connect(impact_callback)
	var drop_system := get_tree().get_first_node_in_group(
		"drop_system"
	) as DropSystem
	if drop_system != null:
		var callback := Callable(self, "_on_drop_collected")
		if not drop_system.drop_collected.is_connected(callback):
			drop_system.drop_collected.connect(callback)
	var player_manager := get_tree().get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	if player_manager != null:
		var callback := Callable(self, "_on_player_spawned")
		if not player_manager.player_spawned.is_connected(callback):
			player_manager.player_spawned.connect(callback)
	for player in get_tree().get_nodes_in_group("players"):
		_connect_weapon_system(player)
		_connect_player_health(player)
	var boss_system := get_tree().get_first_node_in_group(
		"boss_system"
	) as BossSystem
	if boss_system != null:
		var callback := Callable(self, "_on_boss_spawned")
		if not boss_system.boss_spawned.is_connected(callback):
			boss_system.boss_spawned.connect(callback)
		_connect_boss_feedback(boss_system.get_active_boss())
	var enemy_system := get_tree().get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	if enemy_system != null:
		var spawn_callback := Callable(self, "_on_enemy_spawned")
		if not enemy_system.enemy_spawned.is_connected(spawn_callback):
			enemy_system.enemy_spawned.connect(spawn_callback)
		var death_callback := Callable(self, "_on_enemy_died")
		if not enemy_system.enemy_died.is_connected(death_callback):
			enemy_system.enemy_died.connect(death_callback)
	var wave_manager := get_tree().get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	if wave_manager != null:
		var start_callback := Callable(self, "_on_wave_started")
		if not wave_manager.wave_started.is_connected(start_callback):
			wave_manager.wave_started.connect(start_callback)
		var clear_callback := Callable(self, "_on_wave_completed")
		if not wave_manager.wave_completed.is_connected(clear_callback):
			wave_manager.wave_completed.connect(clear_callback)
	var revive_system := get_tree().get_first_node_in_group("revive_system")
	if revive_system != null:
		var revive_callback := Callable(self, "_on_player_revived")
		if not revive_system.is_connected(&"player_revived", revive_callback):
			revive_system.connect(&"player_revived", revive_callback)
	var game_mode_manager := get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	if game_mode_manager != null:
		var result_callback := Callable(self, "_on_run_finished")
		if not game_mode_manager.run_finished.is_connected(result_callback):
			game_mode_manager.run_finished.connect(result_callback)

func _on_projectile_spawned(projectile: Node) -> void:
	audio_manager.play_gameplay_shot(_get_projectile_source_id(projectile))

func _on_projectile_impacted(
	projectile: Node,
	_target: Node,
	applied_damage: int
) -> void:
	if applied_damage > 0:
		audio_manager.play_gameplay_impact(_get_projectile_source_id(projectile))

func _on_drop_collected(drop_data: Dictionary, _collector: Node) -> void:
	audio_manager.play_gameplay_pickup(
		StringName(drop_data.get("type", &"unknown"))
	)

func _on_player_spawned(_player_slot: int, player: Node) -> void:
	_connect_weapon_system(player)
	_connect_player_health(player)

func _connect_player_health(player: Node) -> void:
	var health_component := player.get_node_or_null(
		"HealthComponent"
	) as HealthComponent
	if health_component == null:
		return
	var callback := Callable(self, "_on_player_downed")
	if not health_component.downed.is_connected(callback):
		health_component.downed.connect(callback)

func _on_player_downed() -> void:
	audio_manager.play_run_feedback(&"player_downed")

func _on_player_revived(
	_target: Node,
	_reviver: Node,
	_restored_health: int
) -> void:
	audio_manager.play_run_feedback(&"player_revived")

func _on_enemy_spawned(enemy: Node) -> void:
	var enemy_id := StringName(enemy.get("enemy_id"))
	audio_manager.play_enemy_feedback(&"spawn", enemy_id)
	if enemy.has_signal("attack_telegraph_started"):
		var callback := Callable(self, "_on_enemy_telegraph_started").bind(enemy)
		if not enemy.is_connected("attack_telegraph_started", callback):
			enemy.connect("attack_telegraph_started", callback)

func _on_enemy_died(enemy: Node) -> void:
	audio_manager.play_enemy_feedback(
		&"death",
		StringName(enemy.get("enemy_id"))
	)

func _on_enemy_telegraph_started(
	_duration: float,
	_direction: Vector2,
	enemy: Node
) -> void:
	audio_manager.play_enemy_feedback(
		&"telegraph",
		StringName(enemy.get("enemy_id"))
	)

func _on_wave_started(_wave_index: int) -> void:
	audio_manager.play_run_feedback(&"wave_start")

func _on_wave_completed(_wave_index: int) -> void:
	audio_manager.play_run_feedback(&"wave_clear")

func _on_run_finished(_result: Dictionary) -> void:
	audio_manager.play_run_feedback(&"run_finished")

func _on_boss_spawned(boss: Node) -> void:
	audio_manager.play_boss_feedback(&"boss_spawn")
	_connect_boss_feedback(boss)

func _connect_boss_feedback(boss: Node) -> void:
	if boss == null:
		return
	var telegraph_callback := Callable(self, "_on_boss_telegraph_started")
	if (
		boss.has_signal("attack_telegraph_started")
		and not boss.is_connected(
			"attack_telegraph_started",
			telegraph_callback
		)
	):
		boss.connect("attack_telegraph_started", telegraph_callback)
	var phase_callback := Callable(self, "_on_boss_phase_changed")
	if (
		boss.has_signal("phase_changed")
		and not boss.is_connected("phase_changed", phase_callback)
	):
		boss.connect("phase_changed", phase_callback)

func _on_boss_telegraph_started(
	pattern_id: StringName,
	_duration: float,
	_direction: Vector2
) -> void:
	audio_manager.play_boss_feedback(&"boss_telegraph", pattern_id)

func _on_boss_phase_changed(_phase_index: int) -> void:
	audio_manager.play_boss_feedback(&"boss_phase")

func _connect_weapon_system(player: Node) -> void:
	var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
	if weapon_system == null:
		return
	var reload_callback := Callable(
		self,
		"_on_weapon_reload_started"
	).bind(weapon_system)
	if not weapon_system.reload_started.is_connected(reload_callback):
		weapon_system.reload_started.connect(reload_callback)
	var low_ammo_callback := Callable(
		self,
		"_on_low_ammo_changed"
	).bind(weapon_system)
	if not weapon_system.low_ammo_changed.is_connected(low_ammo_callback):
		weapon_system.low_ammo_changed.connect(low_ammo_callback)
	var fallback_callback := Callable(
		self,
		"_on_fallback_activated"
	).bind(weapon_system)
	if not weapon_system.fallback_activated.is_connected(fallback_callback):
		weapon_system.fallback_activated.connect(fallback_callback)

func _on_weapon_reload_started(
	_duration: float,
	weapon_system: WeaponSystem
) -> void:
	audio_manager.play_weapon_status(
		&"reload",
		_get_weapon_source_id(weapon_system)
	)

func _on_low_ammo_changed(
	is_low: bool,
	_total_ammo: int,
	weapon_system: WeaponSystem
) -> void:
	if is_low:
		audio_manager.play_weapon_status(
			&"low_ammo",
			_get_weapon_source_id(weapon_system)
		)

func _on_fallback_activated(
	_weapon_data: WeaponData,
	weapon_system: WeaponSystem
) -> void:
	if weapon_system.has_special_weapon():
		audio_manager.play_weapon_status(
			&"fallback",
			_get_weapon_source_id(weapon_system)
		)

func _get_projectile_source_id(projectile: Node) -> StringName:
	if projectile == null:
		return &"projectile"
	return StringName(projectile.get("source_id"))

func _get_weapon_source_id(weapon_system: WeaponSystem) -> StringName:
	if weapon_system == null or weapon_system.weapon_data == null:
		return &"weapon"
	return weapon_system.weapon_data.weapon_id
