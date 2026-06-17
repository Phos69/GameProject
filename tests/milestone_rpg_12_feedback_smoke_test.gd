extends SceneTree

var failures: PackedStringArray = []
var finish_requested: bool = false
var player: PlayerController
var effects: GameplayEffects

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene := load("res://game/player/player.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded")
	if player_scene == null:
		await _finish()
		return

	player = player_scene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	await process_frame

	effects = GameplayEffects.new()
	root.add_child(effects)
	await process_frame
	await process_frame

	var rpg_component := player.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	_expect(rpg_component != null, "rpg component is available")
	_expect(effects.effect_spawn_count == 0, "feedback starts without effects")
	if rpg_component == null:
		await _finish()
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

	await _finish()

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
	if finish_requested:
		return
	finish_requested = true
	for _frame in range(5):
		await process_frame
	if effects != null and is_instance_valid(effects):
		effects.queue_free()
		effects = null
	if player != null and is_instance_valid(player):
		player.queue_free()
		player = null
	for _frame in range(5):
		await process_frame
	if failures.is_empty():
		print("MILESTONE_RPG_12_FEEDBACK_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_12_FEEDBACK_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
