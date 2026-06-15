extends Node
class_name SurvivalAmmoDirector

signal supply_crate_spawned(crate: SupplyCrate, reason: StringName)

@export var supply_crate_scene: PackedScene = preload(
	"res://game/drops/supply_crate.tscn"
)
@export var crate_container_path: NodePath = NodePath("../../../World/Pickups")
@export_range(0, 999) var low_special_ammo_threshold: int = 8
@export_range(0.1, 30.0, 0.1) var evaluation_interval: float = 1.0
@export_range(0.0, 120.0, 0.5) var low_ammo_spawn_cooldown: float = 12.0
@export_range(1, 4) var max_active_crates: int = 1
@export var crate_spawn_points: Array[Vector2] = [
	Vector2(0.0, -120.0),
	Vector2(150.0, 70.0),
	Vector2(-150.0, 70.0)
]

var is_running: bool = false
var evaluation_timer: float = 0.0
var spawn_cooldown_timer: float = 0.0
var spawn_index: int = 0
var active_crates: Array[SupplyCrate] = []
var boss_supply_waves: Dictionary = {}
var wave_manager: WaveManager

func _ready() -> void:
	add_to_group("survival_ammo_director")

func _process(delta: float) -> void:
	if not is_running:
		return
	evaluation_timer = maxf(evaluation_timer - delta, 0.0)
	spawn_cooldown_timer = maxf(spawn_cooldown_timer - delta, 0.0)
	if evaluation_timer > 0.0:
		return
	evaluation_timer = evaluation_interval
	evaluate_ammo_pressure()

func start_run() -> void:
	is_running = true
	evaluation_timer = 0.0
	spawn_cooldown_timer = 0.0
	spawn_index = 0
	boss_supply_waves.clear()
	_resolve_wave_manager()

func stop_run(clear_crates: bool = true) -> void:
	is_running = false
	evaluation_timer = 0.0
	spawn_cooldown_timer = 0.0
	if clear_crates:
		for crate in active_crates.duplicate():
			if is_instance_valid(crate):
				crate.queue_free()
	active_crates.clear()

func evaluate_ammo_pressure() -> bool:
	_prune_crates()
	if wave_manager == null:
		_resolve_wave_manager()
	if (
		wave_manager == null
		or wave_manager.state not in [&"spawning", &"combat"]
		or spawn_cooldown_timer > 0.0
		or active_crates.size() >= max_active_crates
		or not _has_low_special_ammo_player()
	):
		return false
	return _spawn_supply_crate(&"low_special_ammo", false) != null

func get_active_crates() -> Array[SupplyCrate]:
	_prune_crates()
	return active_crates.duplicate()

func _resolve_wave_manager() -> void:
	if wave_manager == null:
		wave_manager = get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if wave_manager == null:
		return
	var intermission_callback := Callable(self, "_on_intermission_started")
	if not wave_manager.intermission_started.is_connected(intermission_callback):
		wave_manager.intermission_started.connect(intermission_callback)
	var wave_callback := Callable(self, "_on_wave_configured")
	if not wave_manager.wave_configured.is_connected(wave_callback):
		wave_manager.wave_configured.connect(wave_callback)

func _has_low_special_ammo_player() -> bool:
	for player in get_tree().get_nodes_in_group("players"):
		var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component == null or not health_component.is_alive():
			continue
		var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
		if (
			weapon_system != null
			and weapon_system.has_special_weapon()
			and weapon_system.is_special_ammo_low(low_special_ammo_threshold)
		):
			return true
	return false

func _spawn_supply_crate(reason: StringName, guaranteed: bool) -> SupplyCrate:
	if supply_crate_scene == null or crate_spawn_points.is_empty():
		return null
	_prune_crates()
	if not guaranteed and active_crates.size() >= max_active_crates:
		return null

	var crate := supply_crate_scene.instantiate() as SupplyCrate
	if crate == null:
		return null
	var target_parent := get_node_or_null(crate_container_path)
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent == null:
		return null
	target_parent.add_child(crate)
	crate.global_position = crate_spawn_points[spawn_index % crate_spawn_points.size()]
	spawn_index += 1
	active_crates.append(crate)
	crate.tree_exited.connect(_on_crate_tree_exited.bind(crate))
	spawn_cooldown_timer = low_ammo_spawn_cooldown
	supply_crate_spawned.emit(crate, reason)
	return crate

func _on_intermission_started(next_wave_index: int, _duration: float) -> void:
	if (
		not is_running
		or wave_manager == null
		or not wave_manager.should_spawn_boss(next_wave_index)
		or boss_supply_waves.has(next_wave_index)
	):
		return
	if _spawn_supply_crate(&"boss_preparation", true) != null:
		boss_supply_waves[next_wave_index] = true

func _on_wave_configured(
	wave_index: int,
	_enemy_count: int,
	is_boss_wave: bool
) -> void:
	if not is_running or not is_boss_wave or boss_supply_waves.has(wave_index):
		return
	if _spawn_supply_crate(&"boss_wave_guarantee", true) != null:
		boss_supply_waves[wave_index] = true

func _on_crate_tree_exited(crate: SupplyCrate) -> void:
	active_crates.erase(crate)

func _prune_crates() -> void:
	for crate in active_crates.duplicate():
		if not is_instance_valid(crate) or crate.is_queued_for_deletion():
			active_crates.erase(crate)
