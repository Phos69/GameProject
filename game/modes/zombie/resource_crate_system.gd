extends Node
class_name ResourceCrateSystem

signal crate_rules_configured(biome_id: StringName)
signal resource_crate_spawned(crate: SupplyCrate, crate_id: StringName)

const COMMON_CRATE_LOOT: LootTable = preload(
	"res://game/modes/zombie/crates/common_crate_loot.tres"
)
const MEDICAL_CRATE_LOOT: LootTable = preload(
	"res://game/modes/zombie/crates/medical_crate_loot.tres"
)
const MILITARY_CRATE_LOOT: LootTable = preload(
	"res://game/modes/zombie/crates/military_crate_loot.tres"
)
const TOXIC_CRATE_LOOT: LootTable = preload(
	"res://game/modes/zombie/crates/toxic_crate_loot.tres"
)
const FIRE_CRATE_LOOT: LootTable = preload(
	"res://game/modes/zombie/crates/fire_crate_loot.tres"
)
const FROST_CRATE_LOOT: LootTable = preload(
	"res://game/modes/zombie/crates/frost_crate_loot.tres"
)
const MARSH_CRATE_LOOT: LootTable = preload(
	"res://game/modes/zombie/crates/marsh_crate_loot.tres"
)

@export var supply_crate_scene: PackedScene = preload(
	"res://game/drops/supply_crate.tscn"
)
@export var crate_container_path: NodePath = NodePath(
	"../../../../World/Pickups"
)
@export_range(24.0, 200.0, 4.0) var minimum_crate_spacing: float = 72.0

var active_biome: BiomeDefinition
var is_active: bool = false
var active_crates: Array[SupplyCrate] = []
var world_runtime: WorldRuntime
var active_region_id: StringName = &""

func _ready() -> void:
	add_to_group("resource_crate_system")

func start_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_resolve_world_runtime()
	active_region_id = (
		world_runtime.get_current_region_id()
		if world_runtime != null
		else &""
	)
	_generate_resource_crates()
	crate_rules_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func begin_streaming_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_resolve_world_runtime()
	active_region_id = (
		world_runtime.get_current_region_id()
		if world_runtime != null
		else &""
	)
	crate_rules_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func set_active_biome(biome: BiomeDefinition) -> void:
	active_biome = biome
	is_active = biome != null
	active_region_id = (
		world_runtime.get_current_region_id()
		if world_runtime != null
		else &""
	)
	if active_biome != null:
		crate_rules_configured.emit(active_biome.biome_id)

func stop_run() -> void:
	_clear_runtime()
	is_active = false
	active_biome = null
	active_region_id = &""
	world_runtime = null

func get_active_crate_ids() -> Array[StringName]:
	_prune_crates()
	var crate_ids: Array[StringName] = []
	for crate in active_crates:
		crate_ids.append(StringName(crate.get_meta("biome_crate_id", &"")))
	return crate_ids

func get_active_crates() -> Array[SupplyCrate]:
	_prune_crates()
	return active_crates.duplicate()

func spawn_encounter_crate(
	crate_id: StringName,
	position: Vector2,
	source_id: StringName = &"random_encounter"
) -> SupplyCrate:
	if supply_crate_scene == null or crate_id.is_empty():
		return null
	if not _is_crate_position_valid(position):
		return null
	var container := _get_crate_container()
	if container == null:
		return null
	var crate := supply_crate_scene.instantiate() as SupplyCrate
	if crate == null:
		return null
	crate.name = "%sEncounterCrate" % String(crate_id).capitalize()
	crate.loot_table = _get_loot_table(crate_id)
	crate.set_meta("biome_crate_id", crate_id)
	crate.set_meta("encounter_source_id", source_id)
	crate.add_to_group("biome_resource_crates")
	crate.add_to_group("encounter_rewards")
	crate.add_to_group("world_streaming_pins")
	var visual := crate.get_node_or_null("Visual") as SupplyCrateVisual
	if visual != null:
		visual.configure_crate_type(crate_id)
	container.add_child(crate)
	crate.global_position = position
	active_crates.append(crate)
	crate.tree_exited.connect(_on_crate_tree_exited.bind(crate))
	resource_crate_spawned.emit(crate, crate_id)
	return crate

func is_crate_position_valid(position: Vector2) -> bool:
	return _is_crate_position_valid(position)

func should_spawn_layout_crate(
	crate_id: StringName,
	crate_position: Vector2,
	region_id: StringName,
	index: int
) -> bool:
	if active_biome == null:
		return false
	if not active_biome.crate_ids.has(crate_id):
		return false
	if not _is_crate_position_valid(crate_position):
		return false
	return not is_layout_crate_consumed_for_region(
		region_id,
		_layout_crate_key(index)
	)

func create_layout_crate(
	crate_id: StringName,
	index: int,
	region_id: StringName
) -> SupplyCrate:
	if supply_crate_scene == null:
		return null
	var crate := supply_crate_scene.instantiate() as SupplyCrate
	if crate == null:
		return null
	crate.name = "%sResourceCrate%d" % [
		String(crate_id).capitalize(),
		index + 1
	]
	crate.loot_table = _get_loot_table(crate_id)
	crate.set_meta("biome_crate_id", crate_id)
	crate.set_meta("region_crate_key", _layout_crate_key(index))
	crate.set_meta("region_id", region_id)
	crate.add_to_group("biome_resource_crates")
	var visual := crate.get_node_or_null("Visual") as SupplyCrateVisual
	if visual != null:
		visual.configure_crate_type(crate_id)
	crate.tree_exited.connect(_on_crate_tree_exited.bind(crate))
	crate.opened.connect(_on_layout_crate_opened)
	return crate

func register_streamed_crate(crate: SupplyCrate, crate_id: StringName) -> void:
	if crate == null:
		return
	if not active_crates.has(crate):
		active_crates.append(crate)
	resource_crate_spawned.emit(crate, crate_id)

func unregister_streamed_crate(crate: SupplyCrate) -> void:
	if crate == null:
		return
	active_crates.erase(crate)

func is_layout_crate_consumed_for_region(
	region_id: StringName,
	crate_key: StringName
) -> bool:
	return (
		world_runtime != null
		and not region_id.is_empty()
		and world_runtime.is_region_item_consumed(
			region_id,
			PersistentWorldState.CATEGORY_OPENED_CRATES,
			crate_key
		)
	)

func _generate_resource_crates() -> void:
	if active_biome == null or supply_crate_scene == null:
		return
	var layout := active_biome.environment_layout
	var allowed_ids := active_biome.crate_ids
	var container := _get_crate_container()
	if layout == null or container == null:
		return
	for index in range(layout.crate_positions.size()):
		if index >= layout.crate_ids.size():
			break
		var crate_id := layout.crate_ids[index]
		var crate_position := layout.crate_positions[index]
		if (
			not allowed_ids.has(crate_id)
			or not _is_crate_position_valid(crate_position)
		):
			continue
		var crate_key := _layout_crate_key(index)
		if _is_layout_crate_consumed(crate_key):
			continue
		var crate := supply_crate_scene.instantiate() as SupplyCrate
		if crate == null:
			continue
		crate.name = "%sResourceCrate%d" % [
			String(crate_id).capitalize(),
			index + 1
		]
		crate.loot_table = _get_loot_table(crate_id)
		crate.set_meta("biome_crate_id", crate_id)
		crate.set_meta("region_crate_key", crate_key)
		crate.set_meta("region_id", active_region_id)
		crate.add_to_group("biome_resource_crates")
		var visual := crate.get_node_or_null("Visual") as SupplyCrateVisual
		if visual != null:
			visual.configure_crate_type(crate_id)
		container.add_child(crate)
		crate.global_position = crate_position
		active_crates.append(crate)
		crate.tree_exited.connect(_on_crate_tree_exited.bind(crate))
		crate.opened.connect(_on_layout_crate_opened)
		resource_crate_spawned.emit(crate, crate_id)

func _is_crate_position_valid(position: Vector2) -> bool:
	_prune_crates()
	var obstacle_system := get_tree().get_first_node_in_group(
		"obstacle_system"
	)
	if (
		obstacle_system != null
		and obstacle_system.has_method("is_position_blocked")
		and obstacle_system.is_position_blocked(position)
	):
		return false
	var hazard_system := get_tree().get_first_node_in_group("hazard_system")
	if (
		hazard_system != null
		and hazard_system.has_method("is_position_hazardous")
		and hazard_system.is_position_hazardous(position)
	):
		return false
	for crate in active_crates:
		if (
			is_instance_valid(crate)
			and not crate.is_queued_for_deletion()
			and crate.global_position.distance_to(position) < minimum_crate_spacing
		):
			return false
	return true

func _get_loot_table(crate_id: StringName) -> LootTable:
	match crate_id:
		&"medical":
			return MEDICAL_CRATE_LOOT
		&"military":
			return MILITARY_CRATE_LOOT
		&"biome_toxic":
			return TOXIC_CRATE_LOOT
		&"biome_fire":
			return FIRE_CRATE_LOOT
		&"biome_frost":
			return FROST_CRATE_LOOT
		&"biome_marsh":
			return MARSH_CRATE_LOOT
		_:
			return COMMON_CRATE_LOOT

func _get_crate_container() -> Node:
	var container := get_node_or_null(crate_container_path)
	return container if container != null else get_tree().current_scene

func _clear_runtime() -> void:
	for crate in active_crates:
		if is_instance_valid(crate):
			crate.queue_free()
	active_crates.clear()

func _resolve_world_runtime() -> void:
	if world_runtime == null or not is_instance_valid(world_runtime):
		world_runtime = get_tree().get_first_node_in_group(
			"world_runtime"
		) as WorldRuntime

func _layout_crate_key(index: int) -> StringName:
	return StringName("layout_%d" % index)

func _is_layout_crate_consumed(crate_key: StringName) -> bool:
	return (
		world_runtime != null
		and not active_region_id.is_empty()
		and world_runtime.is_region_item_consumed(
			active_region_id,
			PersistentWorldState.CATEGORY_OPENED_CRATES,
			crate_key
		)
	)

func _on_layout_crate_opened(crate: SupplyCrate, _opener: Node) -> void:
	if crate == null or not is_instance_valid(crate):
		return
	var region_id := StringName(crate.get_meta("region_id", &""))
	var crate_key := StringName(crate.get_meta("region_crate_key", &""))
	if region_id.is_empty() or crate_key.is_empty():
		return
	_resolve_world_runtime()
	if world_runtime != null:
		world_runtime.mark_region_item_consumed(
			region_id,
			PersistentWorldState.CATEGORY_OPENED_CRATES,
			crate_key
		)
	if not crate.is_queued_for_deletion():
		crate.queue_free()

func _on_crate_tree_exited(crate: SupplyCrate) -> void:
	active_crates.erase(crate)

func _prune_crates() -> void:
	for crate in active_crates.duplicate():
		if (
			not is_instance_valid(crate)
			or crate.is_queued_for_deletion()
		):
			active_crates.erase(crate)
