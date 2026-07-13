extends GutTest
## Assets - I cinque boss zombie usano PNG canonici trasparenti e caricabili.

const ZOMBIE_BOSS_ASSETS: Array[Dictionary] = [
	{
		"boss_id": &"grave_colossus",
		"scene_path": "res://game/bosses/zombie/grave_colossus.tscn",
		"asset_path": "res://assets/sprites/bosses/zombie/grave_colossus.png"
	},
	{
		"boss_id": &"gore_charger",
		"scene_path": "res://game/bosses/zombie/gore_charger.tscn",
		"asset_path": "res://assets/sprites/bosses/zombie/gore_charger.png"
	},
	{
		"boss_id": &"plague_spitter",
		"scene_path": "res://game/bosses/zombie/plague_spitter.tscn",
		"asset_path": "res://assets/sprites/bosses/zombie/plague_spitter.png"
	},
	{
		"boss_id": &"bone_mortar",
		"scene_path": "res://game/bosses/zombie/bone_mortar.tscn",
		"asset_path": "res://assets/sprites/bosses/zombie/bone_mortar.png"
	},
	{
		"boss_id": &"carrion_shepherd",
		"scene_path": "res://game/bosses/zombie/carrion_shepherd.tscn",
		"asset_path": "res://assets/sprites/bosses/zombie/carrion_shepherd.png"
	}
]

func test_zombie_boss_png_assets_are_loadable_and_transparent() -> void:
	for definition in ZOMBIE_BOSS_ASSETS:
		var boss_id := StringName(definition.get("boss_id", &""))
		var asset_path := String(definition.get("asset_path", ""))
		assert_eq(
			asset_path,
			"res://assets/sprites/bosses/zombie/%s.png" % String(boss_id),
			"%s uses the canonical PNG path" % String(boss_id)
		)
		var source_exists := FileAccess.file_exists(asset_path)
		assert_true(
			source_exists,
			"%s source PNG exists" % String(boss_id)
		)
		if not source_exists:
			continue
		var image := Image.new()
		var load_error := image.load(ProjectSettings.globalize_path(asset_path))
		assert_eq(load_error, OK, "%s source PNG loads" % String(boss_id))
		if load_error != OK:
			continue
		assert_true(
			image.get_width() > 0 and image.get_height() > 0,
			"%s PNG has valid dimensions" % String(boss_id)
		)
		assert_false(
			image.detect_alpha() == Image.ALPHA_NONE,
			"%s PNG contains transparency" % String(boss_id)
		)
		var corners: Array[Vector2i] = [
			Vector2i.ZERO,
			Vector2i(image.get_width() - 1, 0),
			Vector2i(0, image.get_height() - 1),
			Vector2i(image.get_width() - 1, image.get_height() - 1)
		]
		for corner in corners:
			assert_eq(
				image.get_pixelv(corner).a,
				0.0,
				"%s has a transparent corner at %s" % [boss_id, corner]
			)
		var used_rect := image.get_used_rect()
		assert_true(
			used_rect.size.x > 0 and used_rect.size.y > 0,
			"%s keeps a non-empty opaque silhouette" % String(boss_id)
		)
		var texture := load(asset_path) as Texture2D
		assert_not_null(texture, "%s imports as Texture2D" % String(boss_id))

func test_zombie_boss_scenes_reference_and_load_their_png() -> void:
	for definition in ZOMBIE_BOSS_ASSETS:
		var boss_id := StringName(definition.get("boss_id", &""))
		var scene_path := String(definition.get("scene_path", ""))
		var asset_path := String(definition.get("asset_path", ""))
		var packed := load(scene_path) as PackedScene
		assert_not_null(packed, "%s scene loads" % String(boss_id))
		if packed == null:
			continue
		var boss := packed.instantiate() as ZombieBossBase
		assert_not_null(boss, "%s scene instantiates" % String(boss_id))
		if boss == null:
			continue
		boss.set_physics_process(false)
		add_child(boss)
		var visual := boss.get_node_or_null("Visual") as ZombieBossVisual
		assert_not_null(visual, "%s scene has ZombieBossVisual" % String(boss_id))
		if visual != null:
			assert_eq(
				visual.get_sprite_path(),
				asset_path,
				"%s scene references its canonical PNG" % String(boss_id)
			)
			assert_true(
				visual.uses_sprite_asset(),
				"%s visual loads its PNG instead of the fallback" % String(boss_id)
			)
		boss.free()
