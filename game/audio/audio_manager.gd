extends Node
class_name AudioManager

signal ui_feedback_generated(feedback_type: StringName, frames_written: int)

const MIX_RATE: float = 22050.0

var ui_player: AudioStreamPlayer
var ui_stream: AudioStreamGenerator

func _ready() -> void:
	add_to_group("audio_manager")
	ui_stream = AudioStreamGenerator.new()
	ui_stream.mix_rate = MIX_RATE
	ui_stream.buffer_length = 0.15
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIAudioPlayer"
	ui_player.stream = ui_stream
	ui_player.volume_db = -8.0
	add_child(ui_player)
	ui_player.play()

func play_ui_focus() -> int:
	var frames_written := _play_tone(440.0, 0.035, 0.08)
	ui_feedback_generated.emit(&"focus", frames_written)
	return frames_written

func play_ui_confirm() -> int:
	var frames_written := _play_tone(660.0, 0.07, 0.12)
	ui_feedback_generated.emit(&"confirm", frames_written)
	return frames_written

func _play_tone(frequency: float, duration: float, amplitude: float) -> int:
	if ui_player == null or not ui_player.playing:
		return 0
	var playback := ui_player.get_stream_playback() as AudioStreamGeneratorPlayback
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
