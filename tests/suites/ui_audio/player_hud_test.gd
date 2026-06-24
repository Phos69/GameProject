extends GutTest
## UI/Audio A9 — HUD del giocatore: card d'angolo, HUD world-space e feedback RPG.
##
## Migra e accorpa (tutti istanziano solo player.tscn, niente boot di main.tscn):
##   tests/milestone_rpg_9_hud_smoke_test.gd        (PlayerHudCard + WorldHud)
##   tests/player_world_hud_layout_smoke_test.gd    (snapshot layout WorldHud)
##   tests/milestone_rpg_12_feedback_smoke_test.gd  (GameplayEffects RPG)

const PLAYER_SCENE_PATH := "res://game/player/player.tscn"

# --- card d'angolo + HUD world-space (milestone_rpg_9_hud) -------------------

func test_hud_card_and_world_hud() -> void:
	var player := _spawn_player()
	assert_not_null(player, "player scene can be loaded")
	if player == null:
		return
	await wait_frames(2)

	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	var world_hud := player.get_node("WorldHud")
	assert_not_null(rpg_component, "rpg component is available")
	assert_not_null(world_hud, "world-space player HUD is available")
	if rpg_component == null or world_hud == null:
		player.queue_free()
		return

	player.apply_rpg_character(&"ranger")
	rpg_component.add_experience(20)
	rpg_component.add_adrenaline(100)

	var card := PlayerHudCard.new()
	add_child(card)
	await wait_frames(1)
	card.configure(1, Color(0.18, 0.74, 0.95, 1.0))
	card.refresh(player)

	assert_not_null(card.portrait_icon, "HUD card has a portrait icon")
	assert_eq(card.portrait_icon.icon_id, &"ranger", "portrait follows selected class")
	assert_eq(card.weapon_icon.get_profile_id(), &"rpg_bow", "weapon icon follows base weapon")
	assert_true(card.ammo_pips.is_empty(), "corner card does not duplicate magazine pips")
	assert_null(card.xp_bar, "corner card no longer duplicates XP")
	assert_null(card.adrenaline_bar, "corner card no longer duplicates adrenaline")
	assert_eq(card.slot_label.text, "P1", "corner card keeps the slot label compact")
	assert_eq(world_hud.get_magazine_size(), 1, "world HUD exposes bow magazine")
	assert_eq(world_hud.get_current_ammo(), 1, "world HUD exposes current ammo")
	assert_almost_eq(world_hud.get_exp_ratio(), 20.0 / 45.0, 0.0001, "world HUD exposes per-run XP ratio")
	assert_eq(world_hud.get_level(), 1, "world HUD exposes current level")
	assert_almost_eq(world_hud.get_super_ratio(), 1.0, 0.0001, "world HUD fills super bar at cap")
	assert_true(world_hud.is_super_ready_display(), "world HUD exposes super ready state")

	card.queue_free()
	player.queue_free()

# --- snapshot del layout WorldHud (player_world_hud_layout) ------------------

func test_world_hud_layout_snapshot() -> void:
	var player := _spawn_player()
	assert_not_null(player, "player scene can be loaded")
	if player == null:
		return
	await wait_frames(2)
	player.apply_rpg_character(&"ranger")
	player.rpg_component.add_adrenaline(100)

	var world_hud := player.get_node("WorldHud") as PlayerWorldHudVisual
	assert_not_null(world_hud, "world-space player HUD is available")
	if world_hud == null:
		player.queue_free()
		return

	world_hud.high_contrast = true
	var layout: Dictionary = world_hud.get_layout_snapshot()
	var health_rect: Rect2 = layout.get("health_bar_rect", Rect2())
	var super_rect: Rect2 = layout.get("super_bar_rect", Rect2())
	var health_colors: Array = layout.get("health_colors", [])
	assert_false(
		bool(layout.get("shows_player_label", true)),
		"level ring replaces the player label"
	)
	assert_true(
		StringName(layout.get("health_orientation", &"")) == &"horizontal_two_rows"
		and health_rect.size.x > health_rect.size.y
		and health_rect.size.y >= 2.0 * float(layout.get("status_font_size", 0)),
		"health bar occupies both upper rows"
	)
	if health_colors.size() == 3:
		var healthy_color: Color = health_colors[0]
		var warning_color: Color = health_colors[1]
		var critical_color: Color = health_colors[2]
		assert_true(
			healthy_color.g > healthy_color.r,
			"healthy health stays green in high contrast"
		)
		assert_true(
			warning_color.r > warning_color.b and warning_color.g > warning_color.b,
			"warning health stays orange in high contrast"
		)
		assert_true(
			critical_color.r > critical_color.g,
			"critical health stays red in high contrast"
		)
	else:
		assert_true(false, "health exposes green, orange and red states")
	var super_color: Color = layout.get("super_color", Color.BLACK)
	assert_true(
		StringName(layout.get("super_orientation", &"")) == &"vertical"
		and super_rect.size.y > super_rect.size.x
		and super_rect.size.y >= world_hud.size.y * 0.80,
		"super bar occupies the full vertical edge"
	)
	assert_true(
		super_color.b > super_color.r and super_color.b > super_color.g,
		"super bar is blue"
	)
	assert_true(
		bool(layout.get("ready_glows_faceplate", false))
		and world_hud.is_super_ready_display(),
		"charged super enables the full-faceplate glow"
	)
	assert_true(
		int(layout.get("status_font_size", 0)) >= 10
		and int(layout.get("bar_font_size", 0)) >= 10,
		"HP and ammo use readable base font sizes"
	)

	player.queue_free()

# --- feedback RPG da level up / super (milestone_rpg_12_feedback) ------------

func test_rpg_feedback_effects() -> void:
	var player := _spawn_player()
	assert_not_null(player, "player scene can be loaded")
	if player == null:
		return
	await wait_frames(2)

	var effects := GameplayEffects.new()
	add_child(effects)
	await wait_frames(2)

	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	assert_not_null(rpg_component, "rpg component is available")
	assert_eq(effects.effect_spawn_count, 0, "feedback starts without effects")
	if rpg_component == null:
		effects.queue_free()
		player.queue_free()
		return

	player.apply_rpg_character(&"ranger")
	var before_level_effects := effects.effect_spawn_count
	rpg_component.add_experience(45)
	await wait_frames(1)
	assert_gt(
		effects.effect_spawn_count, before_level_effects,
		"level up spawns RPG feedback"
	)
	assert_true(
		_has_effect_kind(effects, &"rpg_level_up"),
		"level up feedback uses dedicated effect kind"
	)

	var before_super_effects := effects.effect_spawn_count
	rpg_component.super_activated.emit(&"arrow_rain", "Pioggia di Frecce")
	await wait_frames(1)
	assert_gt(
		effects.effect_spawn_count, before_super_effects,
		"super activation spawns RPG feedback"
	)
	assert_true(
		_has_effect_kind(effects, &"rpg_super"),
		"super feedback uses dedicated effect kind"
	)
	var expected_super_kinds := {
		&"arrow_rain": &"rpg_super_cone",
		&"final_barrage": &"rpg_super_burst",
		&"blood_quake": &"rpg_super_radial",
		&"phantom_blade": &"rpg_super_dash",
		&"falling_star": &"rpg_super_radial",
		&"scrap_pack": &"rpg_super_burst",
		&"beast_night": &"rpg_super_dash"
	}
	for super_id in expected_super_kinds.keys():
		var effect := effects.spawn_rpg_super(Vector2.ZERO, super_id)
		await wait_frames(1)
		assert_true(
			effect != null and effect.effect_kind == expected_super_kinds[super_id],
			"%s super feedback has distinct effect kind" % str(super_id)
		)

	await wait_frames(5)
	effects.queue_free()
	player.queue_free()
	await wait_frames(2)

# --- helper -----------------------------------------------------------------

func _spawn_player() -> PlayerController:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		return null
	var player := player_scene.instantiate() as PlayerController
	add_child(player)
	return player

func _has_effect_kind(effects: GameplayEffects, effect_kind: StringName) -> bool:
	for child in effects.get_children():
		if child is GameplayEffect and (child as GameplayEffect).effect_kind == effect_kind:
			return true
	return false
