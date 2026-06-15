extends Node
class_name AudioManager

signal ui_feedback_generated(feedback_type: StringName, frames_written: int)
signal gameplay_feedback_generated(
	feedback_type: StringName,
	source_id: StringName,
	frames_written: int
)

const MIX_RATE: float = 22050.0

var ui_player: AudioStreamPlayer
var ui_stream: AudioStreamGenerator
var gameplay_player: AudioStreamPlayer
var gameplay_stream: AudioStreamGenerator

func _ready() -> void:
	add_to_group("audio_manager")
	ui_player = _create_generator_player("UIAudioPlayer", 0.15, -8.0)
	ui_stream = ui_player.stream as AudioStreamGenerator
	gameplay_player = _create_generator_player(
		"GameplayAudioPlayer",
		0.30,
		-10.0
	)
	gameplay_stream = gameplay_player.stream as AudioStreamGenerator
	call_deferred("_connect_gameplay_sources")

func _create_generator_player(
	player_name: String,
	buffer_length: float,
	volume_db: float
) -> AudioStreamPlayer:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = buffer_length
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player

func play_ui_focus() -> int:
	var frames_written := _play_tone(ui_player, 440.0, 0.035, 0.08)
	ui_feedback_generated.emit(&"focus", frames_written)
	return frames_written

func play_ui_confirm() -> int:
	var frames_written := _play_tone(ui_player, 660.0, 0.07, 0.12)
	ui_feedback_generated.emit(&"confirm", frames_written)
	return frames_written

func play_gameplay_shot(source_id: StringName) -> int:
	var frequency := 260.0 if source_id == &"boss_projectile" else 520.0
	if source_id == &"defense_tower":
		frequency = 380.0
	var frames_written := _play_tone(gameplay_player, frequency, 0.045, 0.09)
	gameplay_feedback_generated.emit(&"shot", source_id, frames_written)
	return frames_written

func play_gameplay_impact(source_id: StringName) -> int:
	var frames_written := _play_tone(gameplay_player, 150.0, 0.055, 0.10)
	gameplay_feedback_generated.emit(&"impact", source_id, frames_written)
	return frames_written

func play_gameplay_pickup(drop_type: StringName) -> int:
	var frequency := 760.0
	match drop_type:
		GameConstants.DROP_AMMO:
			frequency = 700.0
		GameConstants.DROP_HEALTH:
			frequency = 620.0
		GameConstants.DROP_WEAPON:
			frequency = 920.0
		GameConstants.DROP_MONEY:
			frequency = 820.0
	var frames_written := _play_tone(gameplay_player, frequency, 0.08, 0.10)
	gameplay_feedback_generated.emit(&"pickup", drop_type, frames_written)
	return frames_written

func play_weapon_status(
	feedback_type: StringName,
	source_id: StringName
) -> int:
	var frequency := 360.0
	var duration := 0.07
	match feedback_type:
		&"low_ammo":
			frequency = 190.0
			duration = 0.10
		&"reload":
			frequency = 310.0
		&"fallback":
			frequency = 430.0
			duration = 0.11
	var frames_written := _play_tone(
		gameplay_player,
		frequency,
		duration,
		0.09
	)
	gameplay_feedback_generated.emit(feedback_type, source_id, frames_written)
	return frames_written

func _connect_gameplay_sources() -> void:
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
		var drop_callback := Callable(self, "_on_drop_collected")
		if not drop_system.drop_collected.is_connected(drop_callback):
			drop_system.drop_collected.connect(drop_callback)
	var player_manager := get_tree().get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	if player_manager != null:
		var player_callback := Callable(self, "_on_player_spawned")
		if not player_manager.player_spawned.is_connected(player_callback):
			player_manager.player_spawned.connect(player_callback)
	for player in get_tree().get_nodes_in_group("players"):
		_connect_weapon_system(player)

func _on_projectile_spawned(projectile: Node) -> void:
	play_gameplay_shot(_get_projectile_source_id(projectile))

func _on_projectile_impacted(
	projectile: Node,
	_target: Node,
	applied_damage: int
) -> void:
	if applied_damage > 0:
		play_gameplay_impact(_get_projectile_source_id(projectile))

func _on_drop_collected(drop_data: Dictionary, _collector: Node) -> void:
	play_gameplay_pickup(StringName(drop_data.get("type", &"unknown")))

func _on_player_spawned(_player_slot: int, player: Node) -> void:
	_connect_weapon_system(player)

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
	play_weapon_status(&"reload", _get_weapon_source_id(weapon_system))

func _on_low_ammo_changed(
	is_low: bool,
	_total_ammo: int,
	weapon_system: WeaponSystem
) -> void:
	if is_low:
		play_weapon_status(&"low_ammo", _get_weapon_source_id(weapon_system))

func _on_fallback_activated(
	_weapon_data: WeaponData,
	weapon_system: WeaponSystem
) -> void:
	if weapon_system.has_special_weapon():
		play_weapon_status(&"fallback", _get_weapon_source_id(weapon_system))

func _get_projectile_source_id(projectile: Node) -> StringName:
	if projectile == null:
		return &"projectile"
	return StringName(projectile.get("source_id"))

func _get_weapon_source_id(weapon_system: WeaponSystem) -> StringName:
	if weapon_system == null or weapon_system.weapon_data == null:
		return &"weapon"
	return weapon_system.weapon_data.weapon_id

func _play_tone(
	player: AudioStreamPlayer,
	frequency: float,
	duration: float,
	amplitude: float
) -> int:
	if player == null or not player.playing:
		return 0
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return 0
	var frame_count := mini(
		int(duration * MIX_RATE),
		playback.get_frames_available()
	)
	for frame_index in range(frame_count):
		var time := float(frame_index) / MIX_RATE
		var envelope := 1.0 - float(frame_index) / float(maxi(frame_count, 1))
		var sample := sin(TAU * frequency * time) * amplitude * envelope
		playback.push_frame(Vector2(sample, sample))
	return frame_count
