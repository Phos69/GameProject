extends BaseGameMode
class_name InfiniteArenaMode

@export var survival_mode_path: NodePath = NodePath("../SurvivalMode")
@export var arena_size: Vector2i = Vector2i(500, 500)

var survival_mode: SurvivalMode

func _ready() -> void:
	mode_id = GameConstants.MODE_INFINITE_ARENA
	add_to_group("infinite_arena_mode")
	_resolve_survival_mode()

	var game_mode_manager = get_tree().get_first_node_in_group("game_mode_manager")
	if game_mode_manager != null:
		game_mode_manager.register_mode(self)

func _process(_delta: float) -> void:
	if not is_running:
		return
	_resolve_survival_mode()
	if survival_mode != null and not survival_mode.is_running:
		super.stop_mode()

func start_mode(context: Dictionary = {}) -> void:
	if is_running:
		return
	_resolve_survival_mode()
	if survival_mode == null:
		return
	var arena_context := _build_arena_context(context)
	super.start_mode(arena_context)
	survival_mode.start_mode(arena_context)
	if not survival_mode.is_running:
		super.stop_mode()

func stop_mode() -> void:
	if not is_running:
		return
	_resolve_survival_mode()
	if survival_mode != null and survival_mode.is_running:
		survival_mode.stop_mode()
	super.stop_mode()

func _resolve_survival_mode() -> void:
	if survival_mode != null and is_instance_valid(survival_mode):
		return
	if not survival_mode_path.is_empty():
		survival_mode = get_node_or_null(survival_mode_path) as SurvivalMode
	if survival_mode == null:
		survival_mode = get_tree().get_first_node_in_group(
			"survival_mode"
		) as SurvivalMode

func _build_arena_context(context: Dictionary) -> Dictionary:
	var resolved := context.duplicate(true)
	resolved["mode_profile"] = String(GameConstants.MODE_INFINITE_ARENA)
	resolved["single_biome_arena"] = true
	resolved["biome_map_width"] = 1
	resolved["biome_map_height"] = 1
	resolved["biome_cell_width"] = arena_size.x
	resolved["biome_cell_height"] = arena_size.y
	resolved["arena_boundary_mode"] = "walled"
	resolved["disable_world_runtime"] = true
	resolved["disable_region_streaming"] = true
	return resolved
