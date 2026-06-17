extends SceneTree

# Milestone 6 - Asset definitivi e animazioni personaggi RPG.
# Valida la pipeline asset dei sette personaggi: ogni RpgCharacterData ha i path
# popolati e i file presenti in-repo (nessun asset esterno), weapon layer e VFX
# separati, portrait HUD coerente (asset dedicato) e index allineato.
# Non valuta la qualita artistica (manuale), ma la coerenza dati.

const ASSET_PATH_FIELDS: Array[String] = [
	"portrait_full_path",
	"portrait_hud_path",
	"gameplay_sprite_path",
	"sprite_sheet_path",
	"weapon_sprite_path",
	"passive_icon_path",
	"super_icon_path"
]
const KNOWN_STATUS: Array[String] = ["base_complete", "final_quality"]

var failures: PackedStringArray = []

func _initialize() -> void:
	var ids := RpgCharacterRegistry.get_character_ids()
	_expect(ids.size() == 7, "registry exposes the seven RPG characters")

	for character_id in ids:
		_validate_character(character_id)

	_validate_index(ids)

	_finish()

func _validate_character(character_id: StringName) -> void:
	var label := String(character_id)
	var profile := RpgCharacterRegistry.get_character_profile(character_id)
	_expect(not profile.is_empty(), "%s: profile loads" % label)
	if profile.is_empty():
		return

	for field in ASSET_PATH_FIELDS:
		var path := str(profile.get(field, ""))
		_expect(not path.is_empty(), "%s: %s is configured" % [label, field])
		if path.is_empty():
			continue
		_expect(
			path.begins_with("res://assets/characters/"),
			"%s: %s stays in-repo (no external asset)" % [label, field]
		)
		_expect(
			FileAccess.file_exists(path),
			"%s: %s file exists (%s)" % [label, field, path]
		)

	_expect(
		not str(profile.get("animation_profile_id", "")).is_empty(),
		"%s: animation_profile_id is set for idle/run/attack/reload/hurt/death/super" % label
	)

	# Portrait HUD must reference the dedicated compact portrait so Character
	# Select and HUD read a coherent, non-duplicated asset.
	_expect(
		str(profile.get("portrait_hud_path", "")).ends_with("_portrait_hud.svg"),
		"%s: portrait_hud_path uses the dedicated HUD portrait" % label
	)

	# Weapon layer is separate from the body: the base weapon resolves its own
	# visual data, rendered apart from the procedural survivor silhouette.
	var weapon_id := StringName(profile.get("base_weapon_id", &""))
	var weapon_data := RpgCharacterRegistry.load_base_weapon(weapon_id)
	_expect(weapon_data != null, "%s: base weapon '%s' resolves" % [label, str(weapon_id)])
	if weapon_data != null:
		_expect(
			weapon_data.visual_data != null,
			"%s: weapon exposes separate visual data (weapon layer)" % label
		)

func _validate_index(ids: Array[StringName]) -> void:
	var path := "res://assets/characters/index.json"
	_expect(FileAccess.file_exists(path), "character index.json exists")
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_expect(parsed is Dictionary, "index.json parses to an object")
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
		_expect(
			KNOWN_STATUS.has(str(entry.get("status", ""))),
			"index status for %s is a known value" % str(entry_id)
		)
	for character_id in ids:
		_expect(listed.has(character_id), "index.json lists %s" % str(character_id))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("RPG_CHARACTER_ASSET_MANIFEST_SMOKE_TEST: PASS")
		quit(0)
		return
	print("RPG_CHARACTER_ASSET_MANIFEST_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
