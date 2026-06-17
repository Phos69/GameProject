extends Node
class_name VisualSettingsManager

signal visual_settings_changed(settings: Dictionary)

const DEFAULT_SETTINGS: Dictionary = {
	"profile_id": &"default",
	"flash_intensity": 1.0,
	"glow_intensity": 1.0,
	"trail_intensity": 1.0,
	"camera_shake_intensity": 1.0,
	"hud_text_scale": 1.0,
	"high_contrast": false,
	"reduced_motion": false
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

func _enter_tree() -> void:
	add_to_group("visual_settings_manager")

func _exit_tree() -> void:
	for connection in visual_settings_changed.get_connections():
		var callback := connection.get("callable", Callable()) as Callable
		if callback.is_valid() and visual_settings_changed.is_connected(callback):
			visual_settings_changed.disconnect(callback)
	settings.clear()

func _ready() -> void:
	call_deferred("_apply_to_registered_consumers")

static func sync_consumer(consumer: Node) -> void:
	if (
		consumer == null
		or not consumer.is_inside_tree()
		or not consumer.has_method("apply_visual_settings")
	):
		return
	var manager := consumer.get_tree().get_first_node_in_group(
		"visual_settings_manager"
	) as VisualSettingsManager
	if manager != null:
		consumer.apply_visual_settings(manager.get_settings_data())

func apply_profile(profile_id: StringName) -> bool:
	match profile_id:
		&"default":
			settings = DEFAULT_SETTINGS.duplicate(true)
		&"reduced_motion":
			settings = {
				"profile_id": &"reduced_motion",
				"flash_intensity": 0.35,
				"glow_intensity": 0.50,
				"trail_intensity": 0.40,
				"camera_shake_intensity": 0.0,
				"hud_text_scale": 1.10,
				"high_contrast": false,
				"reduced_motion": true
			}
		&"high_contrast":
			settings = {
				"profile_id": &"high_contrast",
				"flash_intensity": 0.70,
				"glow_intensity": 0.90,
				"trail_intensity": 0.80,
				"camera_shake_intensity": 0.35,
				"hud_text_scale": 1.15,
				"high_contrast": true,
				"reduced_motion": false
			}
		_:
			return false
	_notify_settings_changed()
	return true

func set_setting(setting_id: StringName, value: Variant) -> bool:
	if not settings.has(setting_id):
		return false
	match setting_id:
		&"flash_intensity", &"glow_intensity", &"trail_intensity", \
		&"camera_shake_intensity":
			settings[setting_id] = clampf(float(value), 0.0, 1.0)
		&"hud_text_scale":
			settings[setting_id] = clampf(float(value), 0.80, 1.20)
		&"high_contrast", &"reduced_motion":
			settings[setting_id] = bool(value)
		&"profile_id":
			return apply_profile(StringName(value))
		_:
			return false
	settings["profile_id"] = &"custom"
	_notify_settings_changed()
	return true

func get_setting(setting_id: StringName, fallback: Variant = null) -> Variant:
	return settings.get(setting_id, fallback)

func get_settings_data() -> Dictionary:
	return settings.duplicate(true)

func restore_settings_data(data: Dictionary) -> void:
	var restored := DEFAULT_SETTINGS.duplicate(true)
	restored["profile_id"] = StringName(data.get("profile_id", &"custom"))
	restored["flash_intensity"] = clampf(
		float(data.get("flash_intensity", 1.0)),
		0.0,
		1.0
	)
	restored["glow_intensity"] = clampf(
		float(data.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	restored["trail_intensity"] = clampf(
		float(data.get("trail_intensity", 1.0)),
		0.0,
		1.0
	)
	restored["camera_shake_intensity"] = clampf(
		float(data.get("camera_shake_intensity", 1.0)),
		0.0,
		1.0
	)
	restored["hud_text_scale"] = clampf(
		float(data.get("hud_text_scale", 1.0)),
		0.80,
		1.20
	)
	restored["high_contrast"] = bool(data.get("high_contrast", false))
	restored["reduced_motion"] = bool(data.get("reduced_motion", false))
	settings = restored
	_notify_settings_changed()

func _notify_settings_changed() -> void:
	var snapshot := get_settings_data()
	visual_settings_changed.emit(snapshot)
	_apply_to_registered_consumers()

func _apply_to_registered_consumers() -> void:
	for consumer in get_tree().get_nodes_in_group(
		"visual_settings_consumers"
	):
		_apply_to_node(consumer)

func _apply_to_node(node: Node) -> void:
	if (
		not is_instance_valid(node)
		or node.is_queued_for_deletion()
		or not node.has_method("apply_visual_settings")
	):
		return
	node.apply_visual_settings(get_settings_data())
