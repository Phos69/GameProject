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

	assert_false(str(profile.get("animation_profile_id", "")).is_empty(),
		"%s: animation_profile_id is set for idle/run/attack/reload/hurt/death/super" % label)
	assert_true(str(profile.get("portrait_hud_path", "")).ends_with("_portrait_hud.svg"),
		"%s: portrait_hud_path uses the dedicated HUD portrait" % label)

	var weapon_id := StringName(profile.get("base_weapon_id", &""))
	var weapon_data := RpgCharacterRegistry.load_base_weapon(weapon_id)
	assert_not_null(weapon_data, "%s: base weapon '%s' resolves" % [label, str(weapon_id)])
	if weapon_data != null:
		assert_not_null(weapon_data.visual_data, "%s: weapon exposes separate visual data (weapon layer)" % label)
