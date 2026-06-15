extends Resource
class_name AudioCueData

@export var cue_id: StringName = &"cue"
@export var optional_stream: AudioStream
@export var bus_name: StringName = &"SFX"
@export var fallback_frequency: float = 440.0
@export var fallback_duration: float = 0.08
@export var fallback_amplitude: float = 0.10
@export_range(0.0, 0.25, 0.01) var pitch_variation: float = 0.04
@export_range(0, 100, 1) var priority: int = 20
