extends SceneTree

## Verifica i marker direzionali per i minion fuori dalla visuale: esclusione
## degli on-screen, ancoraggio al bordo, colore tematico, scala distanza e cap.

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	for _frame in range(6):
		await process_frame

	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(hud != null, "hud manager is available")
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	_expect(enemy_system != null, "enemy system is available")
	if hud == null or enemy_system == null:
		_finish()
		return
	var markers := hud.offscreen_enemy_markers
	_expect(markers != null, "hud creates the offscreen enemy markers node")
	if markers == null:
		_finish()
		return

	_expect(markers.compute_markers().is_empty(), "no minion yields no marker")

	var canvas_xform := markers.get_viewport().get_canvas_transform()
	var view := markers.get_viewport_rect()
	var inverse := canvas_xform.affine_inverse()
	var on_screen_world := inverse * (view.size * 0.5)
	var off_screen_world := inverse * (view.size + Vector2(700.0, 700.0))

	enemy_system.spawn_enemy(&"toxic_zombie", on_screen_world)
	enemy_system.spawn_enemy(&"toxic_zombie", off_screen_world)

	var result := markers.compute_markers()
	_expect(result.size() == 1, "only the off-screen minion produces a marker")
	if result.size() == 1:
		var marker: Dictionary = result[0]
		var facing: Vector2 = marker["facing"]
		_expect(
			facing.x > 0.0 and facing.y > 0.0,
			"marker points toward the off-screen minion (bottom-right)"
		)
		var border: Vector2 = marker["border"]
		_expect(
			border.x >= 0.0 and border.x <= view.size.x
			and border.y >= 0.0 and border.y <= view.size.y,
			"marker is anchored inside the viewport bounds"
		)
		var margin := OffscreenEnemyMarkers.EDGE_MARGIN
		_expect(
			border.x >= margin - 0.5 and border.x <= view.size.x - margin + 0.5
			and border.y >= margin - 0.5 and border.y <= view.size.y - margin + 0.5,
			"marker stays within the inset edge band"
		)
		var closeness: float = marker["closeness"]
		_expect(
			closeness >= 0.0 and closeness <= 1.0,
			"closeness is normalized between 0 and 1"
		)
		_expect(
			(marker["color"] as Color).is_equal_approx(
				OffscreenEnemyMarkers.THEME_COLORS[&"toxic"]
			),
			"marker inherits the toxic theme color"
		)

	var cap := OffscreenEnemyMarkers.MAX_MARKERS
	for index in range(cap + 8):
		var offset := Vector2(900.0 + index * 12.0, 900.0 + index * 7.0)
		enemy_system.spawn_enemy(&"toxic_zombie", inverse * (view.size + offset))
	_expect(
		markers.compute_markers().size() <= cap,
		"marker count is capped at MAX_MARKERS"
	)

	markers.apply_visual_settings({"high_contrast": true, "reduced_motion": true})
	_expect(
		markers.high_contrast and markers.reduced_motion,
		"visual settings toggle high contrast and reduced motion"
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
		print("OFFSCREEN_ENEMY_MARKERS_SMOKE_TEST: PASS")
		quit(0)
		return
	print("OFFSCREEN_ENEMY_MARKERS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
