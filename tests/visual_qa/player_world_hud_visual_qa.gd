extends SceneTree

const OUTPUT_PATH: String = "res://build/qa/player_world_hud_faceplate.png"
const CHARACTER_IDS: Array[StringName] = [
	&"ranger",
	&"pistoliere",
	&"berserker",
	&"spadaccino",
	&"mago",
	&"domatrice",
	&"licantropo"
]
const HEALTH_RATIOS: Array[float] = [1.0, 0.55, 0.25, 0.80, 0.70, 0.45, 0.90]
const SUPER_AMOUNTS: Array[int] = [0, 45, 100, 100, 65, 85, 100]
const POSITIONS: Array[Vector2] = [
	Vector2(180.0, 215.0),
	Vector2(480.0, 215.0),
	Vector2(780.0, 215.0),
	Vector2(1080.0, 215.0),
	Vector2(300.0, 500.0),
	Vector2(620.0, 500.0),
	Vector2(940.0, 500.0)
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.025, 0.035, 1.0)
	backdrop.size = root.size
	root.add_child(backdrop)

	var player_scene := load("res://game/player/player.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded for faceplate QA")
	if player_scene == null:
		_finish()
		return

	for index in range(CHARACTER_IDS.size()):
		var player := player_scene.instantiate() as PlayerController
		player.player_slot = index % 4 + 1
		player.position = POSITIONS[index]
		root.add_child(player)
		player.set_physics_process(false)
		player.apply_rpg_character(CHARACTER_IDS[index])
		var visual := player.get_node_or_null("Visual") as PlayerVisual
		_expect(
			visual != null and visual.has_character_texture(),
			"%s uses its raster gameplay pictogram" % String(CHARACTER_IDS[index])
		)
		player.rpg_component.add_experience(20 + index * 8)
		player.rpg_component.add_adrenaline(SUPER_AMOUNTS[index])
		player.health_component.current_health = roundi(
			float(player.health_component.max_health) * HEALTH_RATIOS[index]
		)

	for _frame in range(4):
		await process_frame

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/qa")
	)
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "faceplate QA image is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) == OK,
			"faceplate QA screenshot is captured"
		)
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_WORLD_HUD_VISUAL_QA: PASS")
		quit(0)
		return
	print("PLAYER_WORLD_HUD_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
