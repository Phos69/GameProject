extends Node
class_name AudioVoicePool

@export_range(1, 32, 1) var max_voices: int = 12

var voices: Array[Dictionary] = []
var sequence: int = 0

func _exit_tree() -> void:
	stop_all()

func play_stream(
	stream: AudioStream,
	bus_name: StringName,
	volume_db: float,
	pitch_scale: float,
	priority: int
) -> bool:
	if stream == null:
		return false
	var voice := _find_voice(priority)
	if voice.is_empty():
		return false
	var player := voice["player"] as AudioStreamPlayer
	player.stop()
	player.stream = stream
	player.bus = String(bus_name)
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	sequence += 1
	voice["priority"] = priority
	voice["sequence"] = sequence
	return true

func get_active_voice_count() -> int:
	var count := 0
	for voice in voices:
		var player := voice["player"] as AudioStreamPlayer
		if player.playing:
			count += 1
	return count

func stop_all() -> void:
	for voice in voices:
		var player := voice.get("player") as AudioStreamPlayer
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	voices.clear()

func _find_voice(priority: int) -> Dictionary:
	for voice in voices:
		var player := voice["player"] as AudioStreamPlayer
		if not player.playing:
			return voice
	if voices.size() < max_voices:
		return _create_voice()
	var candidate: Dictionary = {}
	for voice in voices:
		if int(voice.get("priority", 0)) > priority:
			continue
		if (
			candidate.is_empty()
			or int(voice.get("priority", 0))
			< int(candidate.get("priority", 0))
			or (
				int(voice.get("priority", 0))
				== int(candidate.get("priority", 0))
				and int(voice.get("sequence", 0))
				< int(candidate.get("sequence", 0))
			)
		):
			candidate = voice
	return candidate

func _create_voice() -> Dictionary:
	var player := AudioStreamPlayer.new()
	player.name = "Voice%d" % (voices.size() + 1)
	add_child(player)
	var voice := {
		"player": player,
		"priority": 0,
		"sequence": 0
	}
	voices.append(voice)
	return voice
