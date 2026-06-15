extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root

	var player_scene := load("res://game/player/player.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded")
	if player_scene == null:
		_finish()
		return

	var player := player_scene.instantiate() as PlayerController
	scene_root.add_child(player)
	await process_frame
	await process_frame

	var effects := GameplayEffects.new()
	scene_root.add_child(effects)
	await process_frame
	await process_frame

	var rpg_component := player.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	_expect(rpg_component != null, "rpg component is available")
	_expect(effects.effect_spawn_count == 0, "feedback starts without effects")
	if rpg_component == null:
		_finish()
		return

	player.apply_rpg_character(&"ranger")
	var before_level_effects := effects.effect_spawn_count
	rpg_component.add_experience(45)
	await process_frame
	_expect(
		effects.effect_spawn_count > before_level_effects,
		"level up spawns RPG feedback"
	)
	_expect(
		_has_effect_kind(effects, &"rpg_level_up"),
		"level up feedback uses dedicated effect kind"
	)

	var before_super_effects := effects.effect_spawn_count
	rpg_component.super_activated.emit(&"arrow_rain", "Pioggia di Frecce")
	await process_frame
	_expect(
		effects.effect_spawn_count > before_super_effects,
		"super activation spawns RPG feedback"
	)
	_expect(
		_has_effect_kind(effects, &"rpg_super"),
		"super feedback uses dedicated effect kind"
	)

	scene_root.queue_free()
	_finish()

func _has_effect_kind(effects: GameplayEffects, effect_kind: StringName) -> bool:
	for child in effects.get_children():
		if child is GameplayEffect and (child as GameplayEffect).effect_kind == effect_kind:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_12_FEEDBACK_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_12_FEEDBACK_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
