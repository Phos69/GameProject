extends Node
class_name EnemySystem

signal enemy_spawn_requested(enemy_id: StringName, position: Vector2)
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)

@export var enemy_scene: PackedScene = preload("res://game/enemies/basic_enemy.tscn")
@export var runner_enemy_scene: PackedScene = preload("res://game/enemies/runner_enemy.tscn")
@export var tank_enemy_scene: PackedScene = preload("res://game/enemies/tank_enemy.tscn")
@export var ranged_enemy_scene: PackedScene = preload("res://game/enemies/ranged_enemy.tscn")
@export var enemy_container_path: NodePath = NodePath("../../World/Enemies")
@export var spawn_initial_enemies: bool = false
@export var initial_spawn_points: Array[Vector2] = []

var active_enemies: Array[Node] = []
var registered_enemy_scenes: Dictionary = {}
var registered_enemy_profiles: Dictionary = {}

const BIOME_ENEMY_PROFILES = [
	preload("res://game/modes/zombie/enemies/toxic_zombie.tres"),
	preload("res://game/modes/zombie/enemies/toxic_exploder.tres"),
	preload("res://game/modes/zombie/enemies/burned_zombie.tres"),
	preload("res://game/modes/zombie/enemies/fire_runner.tres"),
	preload("res://game/modes/zombie/enemies/fire_exploder.tres"),
	preload("res://game/modes/zombie/enemies/frozen_zombie.tres"),
	preload("res://game/modes/zombie/enemies/ice_armored_zombie.tres"),
	preload("res://game/modes/zombie/enemies/heavy_slow_zombie.tres"),
	preload("res://game/modes/zombie/enemies/drowned_zombie.tres"),
	preload("res://game/modes/zombie/enemies/marsh_zombie.tres"),
	preload("res://game/modes/zombie/enemies/water_emerging_zombie.tres"),
	preload("res://game/modes/zombie/enemies/toxic_reaver.tres"),
	preload("res://game/modes/zombie/enemies/ember_hound.tres"),
	preload("res://game/modes/zombie/enemies/glacial_bulwark.tres"),
	preload("res://game/modes/zombie/enemies/mire_stalker.tres")
]

func _ready() -> void:
	add_to_group("enemy_system")
	register_enemy_scene(&"survival_runner", runner_enemy_scene)
	register_enemy_scene(&"survival_tank", tank_enemy_scene)
	register_enemy_scene(&"survival_shooter", ranged_enemy_scene)
	for profile in BIOME_ENEMY_PROFILES:
		register_enemy_profile(profile)
	if spawn_initial_enemies:
		call_deferred("_spawn_initial_enemies")

func register_enemy_scene(enemy_id: StringName, scene: PackedScene) -> void:
	if enemy_id.is_empty() or scene == null:
		return
	registered_enemy_scenes[enemy_id] = scene

func register_enemy_profile(profile: BiomeEnemyProfile) -> void:
	if profile == null or profile.enemy_id.is_empty():
		return
	registered_enemy_profiles[profile.enemy_id] = profile
	register_enemy_scene(profile.enemy_id, enemy_scene)

func get_enemy_profile(enemy_id: StringName) -> BiomeEnemyProfile:
	return registered_enemy_profiles.get(enemy_id) as BiomeEnemyProfile

func spawn_enemy(
	enemy_id: StringName,
	position: Vector2,
	parent: Node = null,
	spawn_config: Dictionary = {}
) -> Node:
	enemy_spawn_requested.emit(enemy_id, position)
	var scene := registered_enemy_scenes.get(enemy_id, enemy_scene) as PackedScene
	if scene == null:
		return null

	var enemy := scene.instantiate()
	var resolved_config := spawn_config.duplicate(true)
	resolved_config["enemy_id"] = enemy_id
	if not resolved_config.has("spawn_region_id"):
		resolved_config["spawn_region_id"] = _resolve_spawn_region_id(position)
	if not resolved_config.has("current_region_id"):
		resolved_config["current_region_id"] = resolved_config["spawn_region_id"]
	var profile := get_enemy_profile(enemy_id)
	if profile != null:
		resolved_config["enemy_profile"] = profile
	if enemy.has_method("configure_spawn"):
		enemy.configure_spawn(resolved_config)
	elif enemy is BasicEnemy:
		(enemy as BasicEnemy).enemy_id = enemy_id
		(enemy as BasicEnemy).configure_wave_scaling(resolved_config)
	if enemy is Node2D:
		(enemy as Node2D).global_position = position

	var target_parent := parent
	if target_parent == null:
		target_parent = get_node_or_null(enemy_container_path)
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(enemy)
	active_enemies.append(enemy)
	if enemy.has_signal("died"):
		enemy.connect("died", Callable(self, "_on_enemy_died"))
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))
	enemy_spawned.emit(enemy)
	return enemy

func get_active_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result

func _spawn_initial_enemies() -> void:
	for spawn_position in initial_spawn_points:
		spawn_enemy(&"basic_zombie", spawn_position)

func _on_enemy_died(enemy: Node) -> void:
	active_enemies.erase(enemy)
	enemy_died.emit(enemy)

func _on_enemy_tree_exited(enemy: Node) -> void:
	active_enemies.erase(enemy)

func _resolve_spawn_region_id(position: Vector2) -> StringName:
	var seam_system := get_tree().get_first_node_in_group("region_seam_system")
	if (
		seam_system != null
		and seam_system.has_method("get_region_id_for_world_position")
	):
		var region_id := StringName(
			seam_system.get_region_id_for_world_position(position)
		)
		if not region_id.is_empty():
			return region_id
	var world_runtime := get_tree().get_first_node_in_group(
		"world_runtime"
	) as WorldRuntime
	if world_runtime != null:
		return world_runtime.get_current_region_id()
	return &""
