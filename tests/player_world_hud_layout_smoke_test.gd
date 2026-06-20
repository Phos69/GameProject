extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene := load("res://game/player/player.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded")
	if player_scene == null:
		_finish()
		return

	var player := player_scene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	await process_frame
	player.apply_rpg_character(&"ranger")
	player.rpg_component.add_adrenaline(100)

	var world_hud := player.get_node("WorldHud") as PlayerWorldHudVisual
	_expect(world_hud != null, "world-space player HUD is available")
	if world_hud == null:
		_finish()
		return

	world_hud.high_contrast = true
	var layout: Dictionary = world_hud.get_layout_snapshot()
	var health_rect: Rect2 = layout.get("health_bar_rect", Rect2())
	var super_rect: Rect2 = layout.get("super_bar_rect", Rect2())
	var health_colors: Array = layout.get("health_colors", [])
	_expect(
		not bool(layout.get("shows_player_label", true)),
		"level ring replaces the player label"
	)
	_expect(
		StringName(layout.get("health_orientation", &"")) == &"horizontal_two_rows"
		and health_rect.size.x > health_rect.size.y
		and health_rect.size.y >= 2.0 * float(layout.get("status_font_size", 0)),
		"health bar occupies both upper rows"
	)
	if health_colors.size() == 3:
		var healthy_color: Color = health_colors[0]
		var warning_color: Color = health_colors[1]
		var critical_color: Color = health_colors[2]
		_expect(
			healthy_color.g > healthy_color.r,
			"healthy health stays green in high contrast"
		)
		_expect(
			warning_color.r > warning_color.b and warning_color.g > warning_color.b,
			"warning health stays orange in high contrast"
		)
		_expect(
			critical_color.r > critical_color.g,
			"critical health stays red in high contrast"
		)
	else:
		_expect(false, "health exposes green, orange and red states")
	var super_color: Color = layout.get("super_color", Color.BLACK)
	_expect(
		StringName(layout.get("super_orientation", &"")) == &"vertical"
		and super_rect.size.y > super_rect.size.x
		and super_rect.size.y >= world_hud.size.y * 0.80,
		"super bar occupies the full vertical edge"
	)
	_expect(
		super_color.b > super_color.r and super_color.b > super_color.g,
		"super bar is blue"
	)
	_expect(
		bool(layout.get("ready_glows_faceplate", false))
		and world_hud.is_super_ready_display(),
		"charged super enables the full-faceplate glow"
	)
	_expect(
		int(layout.get("status_font_size", 0)) >= 10
		and int(layout.get("bar_font_size", 0)) >= 10,
		"HP and ammo use readable base font sizes"
	)

	player.queue_free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_WORLD_HUD_LAYOUT_SMOKE_TEST: PASS")
		quit(0)
		return
	print("PLAYER_WORLD_HUD_LAYOUT_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
