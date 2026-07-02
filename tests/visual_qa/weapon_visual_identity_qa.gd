extends SceneTree

const OUTPUT_DIRECTORY := "res://build/qa"
const VISUAL_QA_RUNTIME = preload(
	"res://tests/visual_qa/helpers/visual_qa_runtime.gd"
)
const PICKUP_SCENE_PATH := "res://game/drops/drop_pickup.tscn"
const PROJECTILE_SCENE_PATH := "res://game/projectiles/projectile.tscn"
const QA_BOARD := preload("res://tests/visual_qa/weapon_visual_identity_qa_board.gd")
const SURVIVAL_QA := preload("res://tests/visual_qa/weapon_visual_identity_survival_qa.gd")
const PICKUP_GRID_FILE := "weapon_visual_identity_pickup_grid.png"
const HELD_HUD_GRID_FILE := "weapon_visual_identity_held_hud_grid.png"
const PROJECTILE_EFFECT_GRID_FILE := "weapon_visual_identity_projectile_effect_grid.png"
const MELEE_SLASH_GRID_FILE := "weapon_visual_identity_melee_slash_grid.png"
const ELEMENTAL_IMPACT_GRID_FILE := "weapon_visual_identity_elemental_impact_grid.png"
const PICKUP_SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver", &"pump_shotgun", &"quick_knife", &"demolition_hammer",
	&"fireball", &"ice_lance", &"chain_lightning"
]
const HELD_HUD_SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver", &"pump_shotgun", &"improvised_sniper", &"rusty_minigun",
	&"quick_knife", &"demolition_hammer", &"fireball", &"unstable_void"
]
const PROJECTILE_SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver", &"pump_shotgun", &"grenade_launcher", &"scrap_railgun",
	&"fireball", &"ice_lance", &"chain_lightning", &"unstable_void"
]
const MELEE_SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"quick_knife", &"heavy_axe", &"demolition_hammer",
	&"spear", &"scythe", &"offensive_shield"
]
const ELEMENTAL_SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"fire_wand", &"ice_lance", &"chain_lightning", &"acid_flask", &"unstable_void"
]
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MIN_SAMPLE_PIXELS := 8

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var pickup_scene := load(PICKUP_SCENE_PATH) as PackedScene
	var projectile_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	_expect(pickup_scene != null, "pickup scene can be loaded for W7 QA")
	_expect(projectile_scene != null, "projectile scene can be loaded for W7 QA")
	if pickup_scene == null or projectile_scene == null:
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)

	await _run_pickup_board(pickup_scene)
	await _run_held_hud_board()
	await _run_projectile_effect_board(projectile_scene)
	await _run_melee_board()
	await _run_elemental_board(projectile_scene)
	var survival_qa := SURVIVAL_QA.new()
	failures.append_array(await survival_qa.run(self, pickup_scene))
	_finish()

func _run_pickup_board(pickup_scene: PackedScene) -> void:
	var cells := _build_cells(PICKUP_SAMPLE_WEAPON_IDS, 4)
	cells.append(_missing_visual_cell(cells.size(), 4))
	var stage := _create_board("W7 - pickup silhouettes", cells)
	for index in range(PICKUP_SAMPLE_WEAPON_IDS.size()):
		var weapon_id := PICKUP_SAMPLE_WEAPON_IDS[index]
		var definition := WeaponCatalog.get_definition(weapon_id)
		_expect(definition != null, "%s pickup QA definition exists" % weapon_id)
		if definition == null:
			continue
		var pickup := pickup_scene.instantiate() as DropPickup
		pickup.setup({
			"type": GameConstants.DROP_WEAPON,
			"amount": 1,
			"weapon_data": definition
		})
		pickup.position = _cell_center(cells[index])
		stage.add_child(pickup)
	var missing := pickup_scene.instantiate() as DropPickup
	missing.setup({"type": GameConstants.DROP_WEAPON, "amount": 1})
	missing.position = _cell_center(cells[-1])
	stage.add_child(missing)
	await _capture_and_validate_board(PICKUP_GRID_FILE, cells, 5)
	_expect(
		missing.visual != null and missing.visual.uses_missing_weapon_visual(),
		"missing weapon sample remains an explicit placeholder"
	)
	await _clear_stage(stage)

func _run_held_hud_board() -> void:
	var cells := _build_cells(HELD_HUD_SAMPLE_WEAPON_IDS, 4)
	var stage := _create_board("W7 - held weapons and HUD icons", cells)
	for index in range(HELD_HUD_SAMPLE_WEAPON_IDS.size()):
		var weapon_id := HELD_HUD_SAMPLE_WEAPON_IDS[index]
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			failures.append("%s held/HUD QA definition missing" % weapon_id)
			continue
		var center := _cell_center(cells[index])
		var player_visual := PlayerVisual.new()
		player_visual.position = center + Vector2(-18.0, -2.0)
		player_visual.scale = Vector2(0.90, 0.90)
		player_visual.set_weapon_data(definition)
		player_visual.set_facing(Vector2(0.94, -0.32).normalized())
		player_visual.set_player_slot((index % 4) + 1)
		player_visual.set_process(false)
		stage.add_child(player_visual)
		var icon := WeaponIcon.new()
		icon.position = center + Vector2(32.0, 20.0)
		icon.size = Vector2(50.0, 32.0)
		icon.set_visual_data(definition.visual_data)
		stage.add_child(icon)
	await _capture_and_validate_board(HELD_HUD_GRID_FILE, cells, 6)
	await _clear_stage(stage)

func _run_projectile_effect_board(projectile_scene: PackedScene) -> void:
	var cells := _build_cells(PROJECTILE_SAMPLE_WEAPON_IDS, 4)
	var stage := _create_board("W7 - projectile, muzzle and impact identity", cells)
	for index in range(PROJECTILE_SAMPLE_WEAPON_IDS.size()):
		var weapon_id := PROJECTILE_SAMPLE_WEAPON_IDS[index]
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			failures.append("%s projectile QA definition missing" % weapon_id)
			continue
		var center := _cell_center(cells[index])
		_spawn_static_projectile(stage, projectile_scene, definition, center)
		_spawn_static_effect(
			stage,
			WeaponVisualRenderer.get_muzzle_effect_kind(definition.visual_data),
			center + Vector2(-58.0, 0.0),
			definition.visual_data.muzzle_color,
			definition.visual_data.muzzle_size * 2.2
		)
		_spawn_static_effect(
			stage,
			WeaponVisualRenderer.get_impact_effect_kind(definition.visual_data),
			center + Vector2(58.0, 0.0),
			WeaponVisualRenderer.get_impact_color(definition.visual_data),
			WeaponVisualRenderer.get_impact_size(definition.visual_data)
		)
	await _capture_and_validate_board(PROJECTILE_EFFECT_GRID_FILE, cells, 6)
	await _clear_stage(stage)

func _run_melee_board() -> void:
	var cells := _build_cells(MELEE_SAMPLE_WEAPON_IDS, 3)
	var stage := _create_board("W7 - melee slash and hit identity", cells)
	for index in range(MELEE_SAMPLE_WEAPON_IDS.size()):
		var weapon_id := MELEE_SAMPLE_WEAPON_IDS[index]
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			failures.append("%s melee QA definition missing" % weapon_id)
			continue
		var center := _cell_center(cells[index])
		var attack := MeleeAttack.new()
		attack.configure(
			center + Vector2(-44.0, 0.0),
			Vector2.RIGHT,
			null,
			definition.damage,
			definition.weapon_id,
			&"rectangle",
			definition.get_resolved_melee_range(),
			definition.get_resolved_melee_width(),
			definition.melee_arc_degrees,
			0.0,
			30.0,
			definition.knockback,
			definition.hitstop,
			definition.max_hit_count,
			definition.visual_data,
			definition.trail_style,
			definition.effect_key
		)
		attack.scale = Vector2(0.72, 0.72)
		stage.add_child(attack)
		attack.set_physics_process(false)
		attack.phase = MeleeAttack.Phase.ACTIVE
		attack.phase_timer = 15.0
		attack.queue_redraw()
		_spawn_static_effect(
			stage,
			WeaponVisualRenderer.get_melee_impact_effect_kind(
				definition.visual_data,
				definition.get_resolved_melee_shape(),
				definition.trail_style
			),
			center + Vector2(72.0, 28.0),
			WeaponVisualRenderer.get_melee_impact_color(definition.visual_data),
			WeaponVisualRenderer.get_melee_impact_size(
				definition.visual_data,
				definition.get_resolved_melee_shape(),
				definition.trail_style
			)
		)
	await _capture_and_validate_board(MELEE_SLASH_GRID_FILE, cells, 5)
	await _clear_stage(stage)

func _run_elemental_board(projectile_scene: PackedScene) -> void:
	var cells := _build_cells(ELEMENTAL_SAMPLE_WEAPON_IDS, 5)
	var stage := _create_board("W7 - elemental projectile and impact language", cells)
	for index in range(ELEMENTAL_SAMPLE_WEAPON_IDS.size()):
		var weapon_id := ELEMENTAL_SAMPLE_WEAPON_IDS[index]
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			failures.append("%s elemental QA definition missing" % weapon_id)
			continue
		var center := _cell_center(cells[index])
		_spawn_static_projectile(
			stage,
			projectile_scene,
			definition,
			center + Vector2(0.0, -34.0)
		)
		_spawn_static_effect(
			stage,
			WeaponVisualRenderer.get_impact_effect_kind(definition.visual_data),
			center + Vector2(0.0, 34.0),
			WeaponVisualRenderer.get_impact_color(definition.visual_data),
			WeaponVisualRenderer.get_impact_size(definition.visual_data) * 1.25
		)
	await _capture_and_validate_board(ELEMENTAL_IMPACT_GRID_FILE, cells, 5)
	await _clear_stage(stage)

func _spawn_static_projectile(
	stage: Node,
	projectile_scene: PackedScene,
	definition: WeaponData,
	position: Vector2
) -> Projectile:
	var projectile := projectile_scene.instantiate() as Projectile
	projectile.position = position
	projectile.launch(
		Vector2.RIGHT, 0.0, null, definition.damage, definition.weapon_id,
		definition.visual_data, 0.0, definition.hitbox_type,
		definition.hitbox_size, definition.max_hit_count
	)
	projectile.lifetime = 30.0
	stage.add_child(projectile)
	projectile.set_physics_process(false)
	return projectile

func _spawn_static_effect(
	stage: Node,
	kind: StringName,
	position: Vector2,
	color: Color,
	size: float
) -> GameplayEffect:
	var effect := GameplayEffect.new()
	effect.position = position
	effect.configure(kind, color, size, 30.0)
	effect.age = 10.0
	stage.add_child(effect)
	effect.set_process(false)
	effect.queue_redraw()
	return effect

func _create_board(title: String, cells: Array[Dictionary]) -> Node2D:
	var stage := Node2D.new()
	stage.name = "WeaponVisualIdentityQaStage"
	root.add_child(stage)
	var board := QA_BOARD.new()
	board.configure(title, cells)
	stage.add_child(board)
	return stage

func _build_cells(ids: Array[StringName], columns: int) -> Array[Dictionary]:
	var labels: Array[String] = []
	for weapon_id in ids:
		labels.append(str(weapon_id))
	return _build_labeled_cells(labels, columns)

func _build_labeled_cells(labels: Array[String], columns: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rows := ceili(float(labels.size()) / float(columns))
	var gap := 16.0
	var margin_x := 42.0
	var top := 78.0
	var cell_width := (VIEWPORT_SIZE.x - margin_x * 2.0 - gap * float(columns - 1)) / float(columns)
	var cell_height := (VIEWPORT_SIZE.y - top - 32.0 - gap * float(rows - 1)) / float(rows)
	for index in range(labels.size()):
		var column := index % columns
		var row := index / columns
		result.append({
			"label": labels[index],
			"rect": Rect2(
				Vector2(
					margin_x + float(column) * (cell_width + gap),
					top + float(row) * (cell_height + gap)
				),
				Vector2(cell_width, cell_height)
			)
		})
	return result

func _missing_visual_cell(index: int, columns: int) -> Dictionary:
	var labels: Array[String] = []
	for weapon_id in PICKUP_SAMPLE_WEAPON_IDS:
		labels.append(str(weapon_id))
	labels.append("missing_visual")
	return _build_labeled_cells(labels, columns)[index]

func _cell_center(cell: Dictionary) -> Vector2:
	var rect := cell.get("rect", Rect2()) as Rect2
	return rect.get_center() + Vector2(0.0, 12.0)

func _sample_rect(cell: Dictionary) -> Rect2i:
	var rect := cell.get("rect", Rect2()) as Rect2
	return Rect2i(
		Vector2i(rect.position + Vector2(12.0, 36.0)),
		Vector2i(rect.size - Vector2(24.0, 48.0))
	)

func _capture_and_validate_board(
	file_name: String,
	cells: Array[Dictionary],
	minimum_unique_signatures: int
) -> void:
	await process_frame
	await process_frame
	_validate_separated_cells(cells)
	var image := await _capture_image(file_name)
	_expect(_is_nonempty_image(image), "%s frame is non-empty" % file_name)
	if image == null:
		return
	var signatures: Dictionary = {}
	for cell in cells:
		var metrics := _region_metrics(image, _sample_rect(cell))
		var label := str(cell.get("label", "sample"))
		_expect(
			int(metrics.get("count", 0)) >= MIN_SAMPLE_PIXELS,
			"%s has visible foreground pixels" % label
		)
		signatures[metrics.get("signature", "empty")] = label
	_expect(
		signatures.size() >= minimum_unique_signatures,
		"%s contains distinct pixel/color signatures" % file_name
	)

func _capture_image(file_name: String) -> Image:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	var output_path := ProjectSettings.globalize_path(
		"%s/%s" % [OUTPUT_DIRECTORY, file_name]
	)
	_expect(image.save_png(output_path) == OK, "%s screenshot is saved" % file_name)
	return image

func _is_nonempty_image(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var metrics := _region_metrics(
		image,
		Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()))
	)
	return int(metrics.get("count", 0)) > 200

func _region_metrics(image: Image, rect: Rect2i) -> Dictionary:
	var clipped := rect.intersection(
		Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()))
	)
	var count := 0
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	var min_x := clipped.end.x
	var min_y := clipped.end.y
	var max_x := clipped.position.x
	var max_y := clipped.position.y
	for y in range(clipped.position.y, clipped.end.y, 2):
		for x in range(clipped.position.x, clipped.end.x, 2):
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) <= 0.16:
				continue
			count += 1
			red += color.r
			green += color.g
			blue += color.b
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	var divisor := maxf(float(count), 1.0)
	var bounds_width := maxi(max_x - min_x, 0)
	var bounds_height := maxi(max_y - min_y, 0)
	var signature := "%d:%d:%d:%d:%d:%d" % [
		count / 4,
		int(red / divisor * 20.0),
		int(green / divisor * 20.0),
		int(blue / divisor * 20.0),
		bounds_width / 4,
		bounds_height / 4,
	]
	return {"count": count, "signature": signature}

func _validate_separated_cells(cells: Array[Dictionary]) -> void:
	var all_separated := true
	for first_index in range(cells.size()):
		var first := _sample_rect(cells[first_index])
		for second_index in range(first_index + 1, cells.size()):
			var second := _sample_rect(cells[second_index])
			if first.intersects(second):
				all_separated = false
	_expect(all_separated, "all QA sample regions are spatially separated")

func _clear_stage(stage: Node) -> void:
	stage.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	var exit_code := 0
	if failures.is_empty():
		print("WEAPON_VISUAL_IDENTITY_QA: PASS")
	else:
		exit_code = 1
		print("WEAPON_VISUAL_IDENTITY_QA: FAIL (%d)" % failures.size())
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
