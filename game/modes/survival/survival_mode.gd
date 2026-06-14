extends BaseGameMode
class_name SurvivalMode

signal survival_defeated(wave_index: int)

@export var boss_wave_interval: int = GameConstants.DEFAULT_BOSS_WAVE_INTERVAL

var wave_manager: WaveManager

func _ready() -> void:
	mode_id = GameConstants.MODE_SURVIVAL
	add_to_group("survival_mode")
	_resolve_wave_manager()

	var game_mode_manager = get_tree().get_first_node_in_group("game_mode_manager")
	if game_mode_manager != null:
		game_mode_manager.register_mode(self)

func _process(_delta: float) -> void:
	if not is_running or wave_manager == null or not wave_manager.run_active:
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	for player in players:
		var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component != null and health_component.is_alive():
			return
	var defeated_wave := wave_manager.current_wave
	wave_manager.stop_run(false)
	survival_defeated.emit(defeated_wave)
	stop_mode()

func start_mode(context: Dictionary = {}) -> void:
	if is_running:
		return
	super.start_mode(context)
	_resolve_wave_manager()
	if wave_manager != null:
		wave_manager.start_run()

func stop_mode() -> void:
	if not is_running:
		return
	if wave_manager != null:
		wave_manager.stop_run(false)
	super.stop_mode()

func should_spawn_boss_for_wave(wave_index: int) -> bool:
	return boss_wave_interval > 0 and wave_index % boss_wave_interval == 0

func _on_boss_wave_requested(wave_index: int) -> void:
	request_boss(StringName("survival_wave_%d" % wave_index))

func _resolve_wave_manager() -> void:
	if wave_manager == null:
		wave_manager = get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if wave_manager == null:
		return
	wave_manager.boss_wave_interval = boss_wave_interval
	var callback := Callable(self, "_on_boss_wave_requested")
	if not wave_manager.boss_wave_requested.is_connected(callback):
		wave_manager.boss_wave_requested.connect(callback)
