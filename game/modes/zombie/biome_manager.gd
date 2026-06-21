extends Node
class_name BiomeManager

signal current_biome_changed(biome_id: StringName, display_name: String)
signal current_region_changed(region_id: StringName, biome_id: StringName)

const INFECTED_PLAINS = preload(
	"res://game/modes/zombie/biomes/infected_plains.tres"
)
const TOXIC_WASTES = preload(
	"res://game/modes/zombie/biomes/toxic_wastes.tres"
)
const BURNING_FIELDS = preload(
	"res://game/modes/zombie/biomes/burning_fields.tres"
)
const FROZEN_OUTSKIRTS = preload(
	"res://game/modes/zombie/biomes/frozen_outskirts.tres"
)
const DROWNED_MARSH = preload(
	"res://game/modes/zombie/biomes/drowned_marsh.tres"
)
const BIOME_WORLD_GENERATOR_SCRIPT = preload(
	"res://game/procedural/world_generation/biome_world_generator.gd"
)

@export var default_biome_id: StringName = &"infected_plains"
@export var biome_definitions: Array[Resource] = []

var biomes: Dictionary = {}
var base_environment_layouts: Dictionary = {}
var base_biome_sizes: Dictionary = {}
var current_biome
var world_generator: BiomeWorldGenerator
var active_world_data: Dictionary = {}
var current_biome_cell: BiomeCell

func _ready() -> void:
	add_to_group("biome_manager")
	_register_builtin_biomes()
	for definition in biome_definitions:
		register_biome(definition)
	_ensure_world_generator()
	select_starting_biome()

func start_run(context: Dictionary = {}) -> void:
	begin_world_build()
	apply_world_data(generate_world_data(context))

# Main-thread reset of any previous world so a fresh generation can run. Must be
# called before generate_world_data() when building asynchronously.
func begin_world_build() -> void:
	_ensure_world_generator()
	_clear_generated_world()
	current_biome_cell = null

# Pure-data world generation. This touches no scene-tree nodes and emits only
# signals nobody listens to, so it is safe to run on a worker thread (after
# begin_world_build() has run on the main thread).
func generate_world_data(context: Dictionary = {}) -> Dictionary:
	if world_generator == null:
		return {}
	return world_generator.generate_world(context, biomes)

# Main-thread install of generated data; select_starting_biome() emits the region
# /biome change signals that build the live world (terrain, hazards, tiles).
func apply_world_data(world_data: Dictionary) -> void:
	active_world_data = world_data
	_apply_generated_layouts()
	select_starting_biome()

func stop_run() -> void:
	_clear_generated_world()

func _exit_tree() -> void:
	_clear_generated_world()

func register_biome(definition) -> void:
	if definition == null:
		return
	var biome_id := StringName(definition.get("biome_id"))
	if biome_id.is_empty():
		return
	biomes[biome_id] = definition
	if not base_environment_layouts.has(biome_id):
		base_environment_layouts[biome_id] = definition.environment_layout
		base_biome_sizes[biome_id] = definition.biome_size

func select_starting_biome() -> bool:
	var start_cell := _get_start_cell()
	if start_cell != null:
		return set_current_region(start_cell.id)
	for definition in biomes.values():
		if definition != null and bool(definition.get("is_starting_biome")):
			return set_current_biome(StringName(definition.get("biome_id")))
	return set_current_biome(default_biome_id)

func set_current_biome(biome_id: StringName) -> bool:
	_update_current_cell_for_biome(biome_id)
	if current_biome_cell != null and current_biome_cell.biome_id == biome_id:
		return set_current_region(current_biome_cell.id)
	var next_biome = biomes.get(biome_id)
	if next_biome == null:
		return false
	if current_biome == next_biome:
		return true
	current_biome = next_biome
	current_biome_changed.emit(
		StringName(current_biome.get("biome_id")),
		String(current_biome.get("display_name"))
	)
	return true

func set_current_region(region_id: StringName) -> bool:
	var cell := get_cell_by_region_id(region_id)
	if cell == null:
		return false
	var next_biome = biomes.get(cell.biome_id)
	if next_biome == null:
		return false
	var previous_biome = current_biome
	current_biome_cell = cell
	current_biome = next_biome
	_apply_cell_layout_to_definition(cell)
	current_region_changed.emit(cell.id, cell.biome_id)
	if previous_biome != current_biome:
		current_biome_changed.emit(
			StringName(current_biome.get("biome_id")),
			String(current_biome.get("display_name"))
		)
	return true

func get_current_biome():
	return current_biome

func get_current_biome_id() -> StringName:
	return StringName(current_biome.get("biome_id")) if current_biome != null else &""

func get_current_display_name() -> String:
	return String(current_biome.get("display_name")) if current_biome != null else ""

func get_biome_definition(biome_id: StringName):
	return biomes.get(biome_id)

func get_available_biome_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for biome_id in biomes.keys():
		ids.append(StringName(biome_id))
	ids.sort()
	return ids

func get_current_biome_cell() -> BiomeCell:
	return current_biome_cell

func get_current_region_id() -> StringName:
	return current_biome_cell.id if current_biome_cell != null else &""

func get_generated_biome_map() -> Array[BiomeCell]:
	if not active_world_data.has("cells"):
		return []
	var result: Array[BiomeCell] = []
	for cell in active_world_data["cells"] as Array:
		var typed_cell := cell as BiomeCell
		if typed_cell != null:
			result.append(typed_cell)
	return result

func get_generation_seed() -> int:
	return int(active_world_data.get("seed", 0))

func get_generation_signature() -> String:
	_ensure_world_generator()
	return world_generator.get_map_signature()

func get_world_graph() -> WorldGraph:
	if active_world_data.has("world_graph"):
		return active_world_data["world_graph"] as WorldGraph
	return null

func get_seed_record() -> Dictionary:
	_ensure_world_generator()
	return world_generator.get_seed_record()

func get_seed_debug_summary() -> String:
	var record := get_seed_record()
	return (
		"global_seed=%d biome_map_rng=%d terrain_rng=%d obstacle_rng=%d"
		% [
			int(record.get("global_seed", 0)),
			int(record.get("biome_map_rng", 0)),
			int(record.get("biome_terrain_rng", 0)),
			int(record.get("obstacle_rng", 0))
		]
	)

func _register_builtin_biomes() -> void:
	register_biome(INFECTED_PLAINS)
	register_biome(TOXIC_WASTES)
	register_biome(BURNING_FIELDS)
	register_biome(FROZEN_OUTSKIRTS)
	register_biome(DROWNED_MARSH)

func _ensure_world_generator() -> void:
	if world_generator != null:
		return
	world_generator = BIOME_WORLD_GENERATOR_SCRIPT.new() as BiomeWorldGenerator
	world_generator.name = "BiomeWorldGenerator"
	add_child(world_generator)
	if world_generator.debug_overlay != null:
		var same_callback := Callable(self, "_on_regenerate_same_seed_requested")
		if not world_generator.debug_overlay.regenerate_same_seed_requested.is_connected(
			same_callback
		):
			world_generator.debug_overlay.regenerate_same_seed_requested.connect(
				same_callback
			)
		var new_callback := Callable(self, "_on_regenerate_new_seed_requested")
		if not world_generator.debug_overlay.regenerate_new_seed_requested.is_connected(
			new_callback
		):
			world_generator.debug_overlay.regenerate_new_seed_requested.connect(
				new_callback
			)

func _apply_generated_layouts() -> void:
	for cell in get_generated_biome_map():
		var definition := biomes.get(cell.biome_id, null) as BiomeDefinition
		if definition == null or cell.generated_layout == null:
			continue
		definition.obstacle_ids = _merge_string_name_arrays(
			definition.obstacle_ids,
			cell.generated_layout.obstacle_ids
		)
		definition.large_obstacle_ids = _merge_string_name_arrays(
			definition.large_obstacle_ids,
			cell.generated_layout.obstacle_ids
		)
		definition.crate_ids = _merge_string_name_arrays(
			definition.crate_ids,
			cell.generated_layout.crate_ids
		)
		definition.hazard_ids = _merge_string_name_arrays(
			definition.hazard_ids,
			cell.generated_layout.hazard_ids
		)
		var passage_types: Array[StringName] = []
		for passage in cell.passages:
			passage_types.append(passage.passage_type)
		definition.passage_type_ids = _merge_string_name_arrays(
			definition.passage_type_ids,
			passage_types
		)
	if current_biome_cell != null:
		_apply_cell_layout_to_definition(current_biome_cell)

func _update_current_cell_for_biome(biome_id: StringName) -> void:
	_ensure_world_generator()
	var next_cell := world_generator.get_neighbor_for_biome(
		current_biome_cell,
		biome_id
	)
	if next_cell != null:
		current_biome_cell = next_cell

func _get_start_cell() -> BiomeCell:
	if active_world_data.has("start_cell"):
		return active_world_data["start_cell"] as BiomeCell
	return null

func get_cell_by_region_id(region_id: StringName) -> BiomeCell:
	for cell in get_generated_biome_map():
		if cell.id == region_id:
			return cell
	return null

func _apply_cell_layout_to_definition(cell: BiomeCell) -> void:
	if cell == null or cell.generated_layout == null:
		return
	var definition := biomes.get(cell.biome_id, null) as BiomeDefinition
	if definition == null:
		return
	definition.environment_layout = cell.generated_layout
	definition.biome_size = cell.generated_layout.zone_size

func _merge_string_name_arrays(
	first: Array[StringName],
	second: Array[StringName]
) -> Array[StringName]:
	var result := first.duplicate()
	for value in second:
		if not result.has(value):
			result.append(value)
	return result

func _on_regenerate_same_seed_requested() -> void:
	_ensure_world_generator()
	_restore_biome_layouts()
	active_world_data = world_generator.regenerate_same_seed(biomes)
	_apply_generated_layouts()
	select_starting_biome()

func _on_regenerate_new_seed_requested() -> void:
	_ensure_world_generator()
	_restore_biome_layouts()
	active_world_data = world_generator.regenerate_new_seed(biomes)
	_apply_generated_layouts()
	select_starting_biome()

func _clear_generated_world() -> void:
	_restore_biome_layouts()
	if world_generator != null:
		world_generator.clear_world()
	active_world_data.clear()
	current_biome_cell = null
	current_biome = biomes.get(default_biome_id, null)

func _restore_biome_layouts() -> void:
	for biome_id in biomes.keys():
		var definition := biomes.get(biome_id, null) as BiomeDefinition
		if definition == null:
			continue
		if base_environment_layouts.has(biome_id):
			definition.environment_layout = (
				base_environment_layouts[biome_id]
				as BiomeEnvironmentLayout
			)
		if base_biome_sizes.has(biome_id):
			definition.biome_size = base_biome_sizes[biome_id]
