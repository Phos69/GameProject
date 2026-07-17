extends Node
class_name AudioManager

signal ui_feedback_generated(feedback_type: StringName, frames_written: int)
signal gameplay_feedback_generated(
	feedback_type: StringName,
	source_id: StringName,
	frames_written: int
)
signal cue_played(
	cue_id: StringName,
	bus_name: StringName,
	used_optional_stream: bool,
	priority: int,
	frames_written: int
)
signal audio_settings_changed(settings: Dictionary)

const MIX_RATE: float = 22050.0
const AUDIO_EVENT_ROUTER := preload("res://game/audio/audio_event_router.gd")
const REQUIRED_BUSES: Array[StringName] = [
	&"Music",
	&"SFX",
	&"UI",
	&"Weapons",
	&"Enemies",
	&"Boss",
	&"Environment"
]

@export var cue_overrides: Array[AudioCueData] = []
@export_range(1, 32, 1) var max_optional_voices: int = 12

var ui_player: AudioStreamPlayer
var ui_stream: AudioStreamGenerator
var gameplay_player: AudioStreamPlayer
var gameplay_stream: AudioStreamGenerator
var generator_players: Dictionary = {}
var cue_registry: Dictionary = {}
var last_cue_pitch: Dictionary = {}
var voice_pool: AudioVoicePool
var rng := RandomNumberGenerator.new()
var is_shutting_down: bool = false

func _ready() -> void:
	add_to_group("audio_manager")
	rng.randomize()
	_ensure_audio_buses()
	_register_default_cues()
	for cue in cue_overrides:
		if cue != null and not cue.cue_id.is_empty():
			cue_registry[cue.cue_id] = cue
	voice_pool = AudioVoicePool.new()
	voice_pool.name = "OptionalVoicePool"
	voice_pool.max_voices = max_optional_voices
	add_child(voice_pool)
	for bus_name in REQUIRED_BUSES:
		if bus_name == &"Music" or bus_name == &"SFX":
			continue
		generator_players[bus_name] = _create_generator_player(
			"%sFallbackPlayer" % bus_name,
			bus_name,
			0.30,
			-10.0
		)
	ui_player = generator_players[&"UI"] as AudioStreamPlayer
	ui_stream = ui_player.stream as AudioStreamGenerator
	gameplay_player = generator_players[&"Weapons"] as AudioStreamPlayer
	gameplay_stream = gameplay_player.stream as AudioStreamGenerator
	var event_router := AUDIO_EVENT_ROUTER.new()
	event_router.name = "AudioEventRouter"
	event_router.audio_manager = self
	add_child(event_router)

func _exit_tree() -> void:
	shutdown_audio()

func shutdown_audio() -> void:
	if is_shutting_down:
		return
	is_shutting_down = true
	if voice_pool != null and is_instance_valid(voice_pool):
		voice_pool.stop_all()
		if voice_pool.get_parent() == self:
			remove_child(voice_pool)
		voice_pool.free()
		voice_pool = null
	for player_value in generator_players.values():
		var player := player_value as AudioStreamPlayer
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
		if player.get_parent() == self:
			remove_child(player)
		player.free()
	generator_players.clear()
	ui_player = null
	ui_stream = null
	gameplay_player = null
	gameplay_stream = null

# Comodita' per i menu: risolvono il manager dal gruppo e suonano il
# feedback UI. Prima ogni menu duplicava lookup e null-check.
static func play_ui_focus_in(tree: SceneTree) -> void:
	var manager := tree.get_first_node_in_group("audio_manager") as AudioManager
	if manager != null:
		manager.play_ui_focus()

static func play_ui_confirm_in(tree: SceneTree) -> void:
	var manager := tree.get_first_node_in_group("audio_manager") as AudioManager
	if manager != null:
		manager.play_ui_confirm()

func play_ui_focus() -> int:
	var frames_written := play_cue(&"ui_focus")
	ui_feedback_generated.emit(&"focus", frames_written)
	return frames_written

func play_ui_confirm() -> int:
	var frames_written := play_cue(&"ui_confirm")
	ui_feedback_generated.emit(&"confirm", frames_written)
	return frames_written

func play_gameplay_shot(source_id: StringName) -> int:
	var bus_name := _shot_bus(source_id)
	var frequency := _shot_frequency(source_id)
	var frames_written := play_cue(
		&"shot",
		source_id,
		bus_name,
		frequency
	)
	gameplay_feedback_generated.emit(&"shot", source_id, frames_written)
	return frames_written

func play_gameplay_impact(source_id: StringName) -> int:
	var bus_name := _shot_bus(source_id)
	var frames_written := play_cue(
		&"impact",
		source_id,
		bus_name,
		150.0
	)
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
	var frames_written := play_cue(
		&"pickup",
		drop_type,
		&"Environment",
		frequency
	)
	gameplay_feedback_generated.emit(&"pickup", drop_type, frames_written)
	return frames_written

func play_weapon_status(
	feedback_type: StringName,
	source_id: StringName
) -> int:
	var cue_id := feedback_type
	var frames_written := play_cue(cue_id, source_id, &"Weapons")
	gameplay_feedback_generated.emit(feedback_type, source_id, frames_written)
	return frames_written

func play_boss_feedback(
	feedback_type: StringName,
	pattern_id: StringName = &"wave_warden"
) -> int:
	var frames_written := play_cue(feedback_type, pattern_id, &"Boss")
	gameplay_feedback_generated.emit(
		feedback_type,
		pattern_id,
		frames_written
	)
	return frames_written

func play_enemy_feedback(
	feedback_type: StringName,
	enemy_id: StringName
) -> int:
	var frequency := 180.0
	match enemy_id:
		&"survival_runner":
			frequency = 245.0
		&"survival_tank":
			frequency = 105.0
		&"survival_shooter":
			frequency = 330.0
		&"toxic_zombie", &"toxic_exploder", &"toxic_reaver":
			frequency = 285.0
		&"burned_zombie", &"fire_runner", &"fire_exploder", &"ember_hound":
			frequency = 360.0
		&"frozen_zombie", &"ice_armored_zombie", &"heavy_slow_zombie", &"glacial_bulwark":
			frequency = 150.0
		&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie", &"mire_stalker":
			frequency = 205.0
	var cue_id := StringName("enemy_%s" % feedback_type)
	var frames_written := play_cue(
		cue_id,
		enemy_id,
		&"Enemies",
		frequency
	)
	gameplay_feedback_generated.emit(cue_id, enemy_id, frames_written)
	return frames_written

func play_run_feedback(feedback_type: StringName) -> int:
	var frames_written := play_cue(feedback_type)
	gameplay_feedback_generated.emit(feedback_type, &"run", frames_written)
	return frames_written

func play_cue(
	cue_id: StringName,
	_source_id: StringName = &"",
	bus_override: StringName = &"",
	frequency_override: float = 0.0
) -> int:
	var cue := cue_registry.get(cue_id) as AudioCueData
	if cue == null:
		cue = _make_cue(cue_id, &"SFX", 440.0, 0.08, 0.09, 20)
	var bus_name := cue.bus_name if bus_override.is_empty() else bus_override
	var pitch := 1.0 + rng.randf_range(
		-cue.pitch_variation,
		cue.pitch_variation
	)
	last_cue_pitch[cue_id] = pitch
	var used_optional_stream := false
	var frames_written := 0
	if cue.optional_stream != null and voice_pool != null:
		used_optional_stream = (
			true
			if _is_headless()
			else voice_pool.play_stream(
				cue.optional_stream,
				bus_name,
				0.0,
				pitch,
				cue.priority
			)
		)
		frames_written = 1 if used_optional_stream else 0
	if not used_optional_stream:
		var player := generator_players.get(bus_name) as AudioStreamPlayer
		if player == null:
			player = gameplay_player
		var frequency := (
			frequency_override
			if frequency_override > 0.0
			else cue.fallback_frequency
		)
		frames_written = _play_tone(
			player,
			frequency * pitch,
			cue.fallback_duration,
			cue.fallback_amplitude
		)
	cue_played.emit(
		cue_id,
		bus_name,
		used_optional_stream,
		cue.priority,
		frames_written
	)
	return frames_written

func set_bus_volume_linear(bus_name: StringName, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(String(bus_name))
	if bus_index < 0:
		return
	var value := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(value) if value > 0.0 else -80.0
	)
	audio_settings_changed.emit(get_settings_data())

func get_bus_volume_linear(bus_name: StringName) -> float:
	var bus_index := AudioServer.get_bus_index(String(bus_name))
	if bus_index < 0:
		return 1.0
	var volume_db := AudioServer.get_bus_volume_db(bus_index)
	return 0.0 if volume_db <= -79.0 else clampf(db_to_linear(volume_db), 0.0, 1.0)

func get_settings_data() -> Dictionary:
	return {
		"master": get_bus_volume_linear(&"Master"),
		"music": get_bus_volume_linear(&"Music"),
		"sfx": get_bus_volume_linear(&"SFX")
	}

func restore_settings_data(data: Dictionary) -> void:
	set_bus_volume_linear(&"Master", float(data.get("master", 1.0)))
	set_bus_volume_linear(&"Music", float(data.get("music", 0.8)))
	set_bus_volume_linear(&"SFX", float(data.get("sfx", 0.9)))

func get_active_optional_voice_count() -> int:
	return voice_pool.get_active_voice_count() if voice_pool != null else 0

func _ensure_audio_buses() -> void:
	for bus_name in REQUIRED_BUSES:
		if AudioServer.get_bus_index(String(bus_name)) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, String(bus_name))
	var sfx_index := AudioServer.get_bus_index("SFX")
	for bus_name in [&"UI", &"Weapons", &"Enemies", &"Boss", &"Environment"]:
		var index := AudioServer.get_bus_index(String(bus_name))
		if index >= 0 and sfx_index >= 0:
			AudioServer.set_bus_send(index, "SFX")

func _create_generator_player(
	player_name: String,
	bus_name: StringName,
	buffer_length: float,
	volume_db: float
) -> AudioStreamPlayer:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = buffer_length
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = String(bus_name)
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player

func _register_default_cues() -> void:
	var cues: Array[AudioCueData] = [
		_make_cue(&"ui_focus", &"UI", 440.0, 0.035, 0.08, 45),
		_make_cue(&"ui_confirm", &"UI", 660.0, 0.07, 0.12, 55),
		_make_cue(&"shot", &"Weapons", 520.0, 0.045, 0.09, 15),
		_make_cue(&"impact", &"Weapons", 150.0, 0.055, 0.10, 12),
		_make_cue(&"pickup", &"Environment", 760.0, 0.08, 0.10, 28),
		_make_cue(&"low_ammo", &"Weapons", 190.0, 0.10, 0.09, 42),
		_make_cue(&"reload", &"Weapons", 310.0, 0.07, 0.09, 24),
		_make_cue(&"fallback", &"Weapons", 430.0, 0.11, 0.09, 38),
		_make_cue(&"boss_spawn", &"Boss", 110.0, 0.20, 0.12, 85),
		_make_cue(&"boss_phase", &"Boss", 95.0, 0.24, 0.13, 90),
		_make_cue(&"boss_telegraph", &"Boss", 220.0, 0.12, 0.10, 80),
		_make_cue(&"enemy_spawn", &"Enemies", 180.0, 0.07, 0.07, 10),
		_make_cue(&"enemy_death", &"Enemies", 120.0, 0.09, 0.08, 18),
		_make_cue(&"enemy_telegraph", &"Enemies", 330.0, 0.12, 0.09, 58),
		_make_cue(&"wave_start", &"Environment", 540.0, 0.14, 0.11, 72),
		_make_cue(&"wave_clear", &"Environment", 740.0, 0.16, 0.11, 72),
		_make_cue(&"rpg_level_up", &"UI", 880.0, 0.18, 0.12, 86),
		_make_cue(&"rpg_super", &"Weapons", 690.0, 0.22, 0.13, 88),
		_make_cue(&"player_downed", &"UI", 135.0, 0.18, 0.12, 92),
		_make_cue(&"player_revived", &"UI", 620.0, 0.18, 0.11, 92),
		_make_cue(&"player_fell", &"Environment", 92.0, 0.22, 0.13, 90),
		_make_cue(&"environment_damage", &"Environment", 170.0, 0.12, 0.10, 62),
		_make_cue(&"biome_entered", &"Environment", 480.0, 0.20, 0.10, 76),
		_make_cue(&"run_finished", &"UI", 260.0, 0.24, 0.12, 96)
	]
	for cue in cues:
		cue_registry[cue.cue_id] = cue

func _make_cue(
	cue_id: StringName,
	bus_name: StringName,
	frequency: float,
	duration: float,
	amplitude: float,
	priority: int
) -> AudioCueData:
	var cue := AudioCueData.new()
	cue.cue_id = cue_id
	cue.bus_name = bus_name
	cue.fallback_frequency = frequency
	cue.fallback_duration = duration
	cue.fallback_amplitude = amplitude
	cue.priority = priority
	return cue

func _shot_bus(source_id: StringName) -> StringName:
	if String(source_id).begins_with("boss_"):
		return &"Boss"
	if String(source_id).begins_with("enemy_"):
		return &"Enemies"
	return &"Weapons"

func _shot_frequency(source_id: StringName) -> float:
	match source_id:
		&"starter_pistol":
			return 520.0
		&"prototype_blaster":
			return 640.0
		&"wave_cannon":
			return 330.0
		&"defense_tower":
			return 380.0
		&"enemy_shooter":
			return 290.0
		&"rpg_bow":
			return 610.0
		&"rpg_pistol":
			return 560.0
		&"rpg_axe":
			return 210.0
		&"rpg_sword":
			return 430.0
		&"rpg_claws":
			return 470.0
		_:
			return 260.0 if String(source_id).begins_with("boss_") else 500.0

func _play_tone(
	player: AudioStreamPlayer,
	frequency: float,
	duration: float,
	amplitude: float
) -> int:
	if _is_headless():
		return maxi(int(duration * MIX_RATE), 1)
	if player == null or player.stream == null:
		return 0
	if not player.playing:
		player.play()
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

func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"
