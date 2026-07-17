extends Node2D
class_name SettingsAwareVisual

# Base per i visual che consumano le impostazioni video di accessibilita'
# (flash/glow/reduced motion): registrazione al gruppo, sync iniziale e
# apply_visual_settings erano duplicati identici in DefenseTowerVisual,
# RiftArchitectVisual e WaveWardenVisual (gruppo 4.5 del report repo health).

var animation_time: float = 0.0
var flash_intensity: float = 1.0
var glow_intensity: float = 1.0
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	flash_intensity = clampf(
		float(settings.get("flash_intensity", 1.0)),
		0.0,
		1.0
	)
	glow_intensity = clampf(
		float(settings.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()
