extends GutTest
## Assets A4 — Pipeline asset dei personaggi RPG (coerenza dati, non qualità).
##
## Migra: tests/rpg_character_asset_manifest_smoke_test.gd
## Valida che ogni RpgCharacterData abbia i path popolati e i file presenti in-repo
## (nessun asset esterno), weapon layer e VFX separati, portrait HUD dedicato e
## index allineato.

const ASSET_PATH_FIELDS: Array[String] = [
	"portrait_full_path", "portrait_hud_path", "gameplay_sprite_path", "sprite_sheet_path",
	"weapon_sprite_path", "passive_icon_path", "super_icon_path"
]
const KNOWN_STATUS: Array[String] = ["base_complete", "final_quality"]

func test_seven_characters() -> void:
	assert_eq(RpgCharacterRegistry.get_character_ids().size(), 7, "registry exposes the seven RPG characters")

func test_character_assets_in_repo() -> void:
	for character_id in RpgCharacterRegistry.get_character_ids():
		_validate_character(character_id)

func test_index_alignment() -> void:
	var ids := RpgCharacterRegistry.get_character_ids()
	var path := "res://assets/characters/index.json"
	assert_true(FileAccess.file_exists(path), "character index.json exists")
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary, "index.json parses to an object")
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	var listed: Dictionary = {}
	for entry_value in data.get("characters", []) as Array:
		var entry := entry_value as Dictionary
		if entry == null:
			continue
		var entry_id := StringName(str(entry.get("id", "")))
		listed[entry_id] = true
		assert_true(KNOWN_STATUS.has(str(entry.get("status", ""))), "index status for %s is a known value" % str(entry_id))
	for character_id in ids:
		assert_true(listed.has(character_id), "index.json lists %s" % str(character_id))

func _validate_character(character_id: StringName) -> void:
	var label := String(character_id)
	var profile := RpgCharacterRegistry.get_character_profile(character_id)
	assert_false(profile.is_empty(), "%s: profile loads" % label)
	if profile.is_empty():
		return

	for field in ASSET_PATH_FIELDS:
		var path := str(profile.get(field, ""))
		assert_false(path.is_empty(), "%s: %s is configured" % [label, field])
		if path.is_empty():
			continue
		assert_true(path.begins_with("res://assets/characters/"), "%s: %s stays in-repo (no external asset)" % [label, field])
		assert_true(FileAccess.file_exists(path), "%s: %s file exists (%s)" % [label, field, path])

	var gameplay_sprite_path := str(profile.get("gameplay_sprite_path", ""))
	assert_true(
		gameplay_sprite_path.ends_with("_gameplay_pictogram.png"),
		"%s: gameplay preview uses the generated raster pictogram" % label
	)
	var pictogram := Image.load_from_file(
		ProjectSettings.globalize_path(gameplay_sprite_path)
	)
	assert_false(pictogram.is_empty(), "%s: pictogram loads as Image" % label)
	if not pictogram.is_empty():
		assert_eq(pictogram.get_size(), Vector2i(512, 512), "%s: pictogram uses the canonical canvas" % label)
		assert_lt(pictogram.get_pixel(0, 0).a, 0.01, "%s: pictogram background is transparent" % label)

	var directional_atlas_path := str(profile.get("directional_roll_atlas_path", ""))
	assert_false(
		directional_atlas_path.is_empty(),
		"%s: directional roll atlas is configured" % label
	)
	if not directional_atlas_path.is_empty():
		assert_true(
			directional_atlas_path.begins_with("res://assets/characters/"),
			"%s: directional atlas stays in-repo" % label
		)
		assert_true(
			FileAccess.file_exists(directional_atlas_path),
			"%s: directional atlas exists" % label
		)
		var atlas := Image.load_from_file(
			ProjectSettings.globalize_path(directional_atlas_path)
		)
		assert_false(atlas.is_empty(), "%s: directional atlas loads as Image" % label)
		if not atlas.is_empty():
			assert_eq(atlas.get_width() % 4, 0, "%s: atlas width divides into four frames" % label)
			assert_eq(atlas.get_height() % 4, 0, "%s: atlas height divides into four directions" % label)
			assert_lt(atlas.get_pixel(0, 0).a, 0.01, "%s: atlas background is transparent" % label)
			_assert_directional_atlas_cells(atlas, label)

	assert_false(str(profile.get("animation_profile_id", "")).is_empty(),
		"%s: animation_profile_id is set for idle/run/attack/reload/hurt/death/super" % label)
	assert_true(str(profile.get("portrait_hud_path", "")).ends_with("_portrait_hud.svg"),
		"%s: portrait_hud_path uses the dedicated HUD portrait" % label)

	var weapon_id := StringName(profile.get("base_weapon_id", &""))
	var weapon_data := RpgCharacterRegistry.load_base_weapon(weapon_id)
	assert_not_null(weapon_data, "%s: base weapon '%s' resolves" % [label, str(weapon_id)])
	if weapon_data != null:
		assert_not_null(weapon_data.visual_data, "%s: weapon exposes separate visual data (weapon layer)" % label)


func _assert_directional_atlas_cells(atlas: Image, label: String) -> void:
	var cell_size := atlas.get_size() / 4
	for row in range(4):
		for column in range(4):
			var origin := Vector2i(column * cell_size.x, row * cell_size.y)
			var opaque_pixels := 0
			for y in range(origin.y, origin.y + cell_size.y):
				for x in range(origin.x, origin.x + cell_size.x):
					if atlas.get_pixel(x, y).a > 0.05:
						opaque_pixels += 1
			assert_gt(
				opaque_pixels,
				0,
				"%s: atlas cell %d,%d contains a visible frame" % [label, column, row]
			)
			var edge_max_alpha := 0.0
			for x in range(origin.x, origin.x + cell_size.x):
				edge_max_alpha = maxf(edge_max_alpha, atlas.get_pixel(x, origin.y).a)
				edge_max_alpha = maxf(
					edge_max_alpha,
					atlas.get_pixel(x, origin.y + cell_size.y - 1).a
				)
			for y in range(origin.y, origin.y + cell_size.y):
				edge_max_alpha = maxf(edge_max_alpha, atlas.get_pixel(origin.x, y).a)
				edge_max_alpha = maxf(
					edge_max_alpha,
					atlas.get_pixel(origin.x + cell_size.x - 1, y).a
				)
			assert_lt(
				edge_max_alpha,
				0.01,
				"%s: cell %d,%d keeps transparent edge padding" % [label, column, row]
			)
