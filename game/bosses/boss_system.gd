extends Node
class_name BossSystem

signal boss_requested(mode_id: StringName, reason: StringName)
signal boss_spawned(boss: Node)
signal boss_defeated(mode_id: StringName)
signal boss_defeated_detailed(
	mode_id: StringName,
	boss_id: StringName,
	display_name: String
)
signal boss_request_rejected(
	mode_id: StringName,
	boss_id: StringName,
	reason: StringName
)

@export var boss_scene: PackedScene = preload("res://game/bosses/basic_boss.tscn")
@export var rift_architect_scene: PackedScene = preload(
	"res://game/bosses/rift_architect.tscn"
)
@export var grave_colossus_scene: PackedScene = preload(
	"res://game/bosses/zombie/grave_colossus.tscn"
)
@export var gore_charger_scene: PackedScene = preload(
	"res://game/bosses/zombie/gore_charger.tscn"
)
@export var plague_spitter_scene: PackedScene = preload(
	"res://game/bosses/zombie/plague_spitter.tscn"
)
@export var bone_mortar_scene: PackedScene = preload(
	"res://game/bosses/zombie/bone_mortar.tscn"
)
@export var carrion_shepherd_scene: PackedScene = preload(
	"res://game/bosses/zombie/carrion_shepherd.tscn"
)
@export var boss_container_path: NodePath = NodePath("../../World/Bosses")

var active_boss: Node
var active_mode_id: StringName = &""
var active_boss_id: StringName = &""
var registered_boss_scenes: Dictionary = {}
var boss_compatible_modes: Dictionary = {}

func _ready() -> void:
	add_to_group("boss_system")
	register_boss_scene(
		&"wave_warden",
		boss_scene,
		[
			GameConstants.MODE_INFINITE_ARENA,
			GameConstants.MODE_SURVIVAL,
			GameConstants.MODE_DUNGEON,
			GameConstants.MODE_TOWER_DEFENSE
		]
	)
	register_boss_scene(
		&"rift_architect",
		rift_architect_scene,
		[
			GameConstants.MODE_INFINITE_ARENA,
			GameConstants.MODE_SURVIVAL,
			GameConstants.MODE_DUNGEON
		]
	)
	var zombie_boss_modes: Array[StringName] = [
		GameConstants.MODE_INFINITE_ARENA,
		GameConstants.MODE_SURVIVAL
	]
	register_boss_scene(
		&"grave_colossus",
		grave_colossus_scene,
		zombie_boss_modes
	)
	register_boss_scene(
		&"gore_charger",
		gore_charger_scene,
		zombie_boss_modes
	)
	register_boss_scene(
		&"plague_spitter",
		plague_spitter_scene,
		zombie_boss_modes
	)
	register_boss_scene(
		&"bone_mortar",
		bone_mortar_scene,
		zombie_boss_modes
	)
	register_boss_scene(
		&"carrion_shepherd",
		carrion_shepherd_scene,
		zombie_boss_modes
	)

func register_boss_scene(
	boss_id: StringName,
	scene: PackedScene,
	compatible_modes: Array[StringName]
) -> void:
	if boss_id.is_empty() or scene == null:
		return
	registered_boss_scenes[boss_id] = scene
	boss_compatible_modes[boss_id] = compatible_modes.duplicate()

func request_boss(
	mode_id: StringName,
	reason: StringName,
	position: Vector2 = Vector2.ZERO,
	parent: Node = null,
	config: Dictionary = {}
) -> Node:
	boss_requested.emit(mode_id, reason)
	if is_instance_valid(active_boss) and not active_boss.is_queued_for_deletion():
		return active_boss
	var requested_boss_id := StringName(config.get("boss_id", &"wave_warden"))
	if not registered_boss_scenes.has(requested_boss_id):
		boss_request_rejected.emit(mode_id, requested_boss_id, &"unknown_boss")
		return null
	if not is_boss_compatible(requested_boss_id, mode_id):
		boss_request_rejected.emit(
			mode_id,
			requested_boss_id,
			&"incompatible_mode"
		)
		return null
	var requested_scene := registered_boss_scenes.get(
		requested_boss_id
	) as PackedScene
	if requested_scene == null:
		return null

	var boss := requested_scene.instantiate()
	if boss.has_method("configure_boss"):
		boss.configure_boss(config)
	if boss is Node2D:
		(boss as Node2D).global_position = position

	var target_parent := parent
	if target_parent == null:
		target_parent = get_node_or_null(boss_container_path)
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(boss)
	active_boss = boss
	active_mode_id = mode_id
	active_boss_id = requested_boss_id
	if boss.has_signal("died"):
		boss.connect("died", Callable(self, "_on_boss_died"))
	boss.tree_exited.connect(_on_boss_tree_exited.bind(boss))
	boss_spawned.emit(boss)
	return boss

func request_boss_by_id(
	boss_id: StringName,
	mode_id: StringName,
	reason: StringName,
	position: Vector2 = Vector2.ZERO,
	parent: Node = null,
	config: Dictionary = {}
) -> Node:
	var request_config := config.duplicate(true)
	request_config["boss_id"] = boss_id
	return request_boss(
		mode_id,
		reason,
		position,
		parent,
		request_config
	)

func is_boss_compatible(boss_id: StringName, mode_id: StringName) -> bool:
	var compatible_modes: Array = boss_compatible_modes.get(boss_id, [])
	return compatible_modes.has(mode_id)

func get_registered_boss_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for boss_id in registered_boss_scenes.keys():
		result.append(StringName(boss_id))
	result.sort()
	return result

func notify_boss_defeated(mode_id: StringName) -> void:
	boss_defeated.emit(mode_id)

func get_active_boss() -> Node:
	if is_instance_valid(active_boss) and not active_boss.is_queued_for_deletion():
		return active_boss
	return null

func _on_boss_died(_boss: Node) -> void:
	var defeated_mode := active_mode_id
	var defeated_boss_id := active_boss_id
	var defeated_display_name := str(_boss.get("display_name"))
	active_boss = null
	active_mode_id = &""
	active_boss_id = &""
	notify_boss_defeated(defeated_mode)
	boss_defeated_detailed.emit(
		defeated_mode,
		defeated_boss_id,
		defeated_display_name
	)

func _on_boss_tree_exited(boss: Node) -> void:
	if active_boss == boss:
		active_boss = null
		active_mode_id = &""
		active_boss_id = &""
