extends BaseGameMode
class_name SurvivalMode

signal survival_defeated(wave_index: int)

@export var boss_wave_interval: int = GameConstants.DEFAULT_BOSS_WAVE_INTERVAL
@export var boss_spawn_position: Vector2 = Vector2(0.0, -220.0)
@export var boss_health_scale_per_wave: float = 0.10
@export var boss_damage_scale_per_wave: float = 0.08

var wave_manager: WaveManager
var ammo_director: SurvivalAmmoDirector
var market_controller: SurvivalMarketController
var zombie_mode_controller

func _ready() -> void:
	mode_id = GameConstants.MODE_SURVIVAL
	add_to_group("survival_mode")
	_resolve_wave_manager()
	_resolve_ammo_director()
	_resolve_market_controller()
	_resolve_zombie_mode_controller()
	_resolve_player_manager()

	var game_mode_manager = get_tree().get_first_node_in_group("game_mode_manager")
	if game_mode_manager != null:
		game_mode_manager.register_mode(self)

func _process(_delta: float) -> void:
	if not is_running or wave_manager == null or not wave_manager.run_active:
		return
	if PlayerQuery.all(get_tree()).is_empty():
		return
	if PlayerQuery.any_alive(get_tree()):
		return
	var defeated_wave := wave_manager.current_wave
	survival_defeated.emit(defeated_wave)
	# Park the built world on defeat: a retry is the most likely next action, so the
	# same-seed world is reused instantly instead of rebuilt. A full teardown still
	# happens if the player leaves to the menu / another mode (stop_mode without
	# keep_world), see stop_mode() below.
	stop_mode(true)

func start_mode(context: Dictionary = {}) -> void:
	if is_running:
		return
	var resolved_context := context.duplicate(true)
	# Real runs build the world on a worker thread behind the loading screen so the
	# window never freezes (Zombie Survival's 3x3 megamap is the heaviest build).
	# Headless tests keep the synchronous, deterministic path unless they opt in.
	if (
		not resolved_context.has("async_world_build")
		and not resolved_context.has(&"async_world_build")
		and DisplayServer.get_name() != "headless"
	):
		resolved_context["async_world_build"] = true
	# BaseGameMode applica il roster personaggi (selected_character_id /
	# selected_character_ids_by_slot) ai player gia presenti durante super.start_mode.
	super.start_mode(resolved_context)
	_resolve_wave_manager()
	_resolve_ammo_director()
	_resolve_market_controller()
	_resolve_zombie_mode_controller()
	if zombie_mode_controller != null:
		# Reuses the parked world instantly, or awaits the worker-thread build when
		# the context requests it (async_world_build); sync path returns immediately.
		await zombie_mode_controller.start_run(resolved_context)
	if not is_running:
		# The run was stopped while the world was building (e.g. back to menu).
		return
	if ammo_director != null:
		ammo_director.start_run()
	if market_controller != null:
		market_controller.start_run()
	if wave_manager != null:
		wave_manager.start_run()

func stop_mode(keep_world: bool = false) -> void:
	# Gameplay-layer stop only runs when the mode is actually running.
	if is_running:
		if ammo_director != null:
			ammo_director.stop_run(true)
		if wave_manager != null:
			wave_manager.stop_run(true)
		if market_controller != null:
			market_controller.stop_run()
	# World stop is propagated even when not running: after a defeat parked the world
	# (stop_mode(true)), leaving to the menu/another mode (stop_mode without
	# keep_world) must still tear down the parked world instead of leaking it.
	_resolve_zombie_mode_controller()
	if zombie_mode_controller != null:
		zombie_mode_controller.stop_run(keep_world)
	super.stop_mode(keep_world)

func should_spawn_boss_for_wave(wave_index: int) -> bool:
	return boss_wave_interval > 0 and wave_index % boss_wave_interval == 0

func _on_boss_wave_requested(wave_index: int) -> void:
	var game_mode_manager = get_tree().get_first_node_in_group("game_mode_manager")
	if game_mode_manager == null or wave_manager == null:
		return
	var wave_offset := maxi(wave_index - 1, 0)
	var config := {
		"boss_id": &"wave_warden",
		"wave_index": wave_index,
		"health_multiplier": 1.0 + float(wave_offset) * boss_health_scale_per_wave,
		"damage_multiplier": 1.0 + float(wave_offset) * boss_damage_scale_per_wave
	}
	var boss: Node = game_mode_manager.request_boss(
		StringName("survival_wave_%d" % wave_index),
		boss_spawn_position,
		null,
		config
	)
	wave_manager.register_wave_boss(boss)

func _resolve_wave_manager() -> void:
	if wave_manager == null:
		wave_manager = get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if wave_manager == null:
		return
	wave_manager.boss_wave_interval = boss_wave_interval
	var callback := Callable(self, "_on_boss_wave_requested")
	if not wave_manager.boss_wave_requested.is_connected(callback):
		wave_manager.boss_wave_requested.connect(callback)

func _resolve_ammo_director() -> void:
	if ammo_director == null:
		ammo_director = get_node_or_null("AmmoDirector") as SurvivalAmmoDirector

func _resolve_market_controller() -> void:
	if market_controller == null:
		market_controller = get_node_or_null(
			"MarketController"
		) as SurvivalMarketController

func _resolve_zombie_mode_controller() -> void:
	if zombie_mode_controller == null:
		zombie_mode_controller = get_tree().get_first_node_in_group(
			"zombie_mode_controller"
		)

