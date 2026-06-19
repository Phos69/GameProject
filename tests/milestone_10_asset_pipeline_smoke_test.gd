extends SceneTree

const REQUIRED_DIRS: Array[String] = [
	"res://assets/environment/isometric/tiles/plains",
	"res://assets/environment/isometric/tiles/toxic",
	"res://assets/environment/isometric/tiles/ash",
	"res://assets/environment/isometric/tiles/snow",
	"res://assets/environment/isometric/tiles/marsh",
	"res://assets/environment/isometric/tiles/forest",
	"res://assets/environment/isometric/tiles/shared",
	"res://assets/environment/isometric/objects/houses",
	"res://assets/environment/isometric/objects/barriers",
	"res://assets/environment/isometric/objects/debris",
	"res://assets/environment/isometric/objects/fences",
	"res://assets/environment/isometric/objects/rocks",
	"res://assets/environment/isometric/objects/trees",
	"res://assets/environment/isometric/objects/vegetation",
	"res://assets/environment/isometric/objects/wrecks",
	"res://assets/environment/isometric/objects/barrels",
	"res://assets/environment/isometric/objects/bridges",
	"res://assets/environment/isometric/objects/crates",
	"res://assets/environment/isometric/edges/cliffs",
	"res://assets/environment/isometric/edges/walls",
	"res://assets/environment/isometric/edges/void",
	"res://assets/environment/isometric/passages",
	"res://assets/environment/isometric/previews"
]
const CONTRACT_SECTIONS: Array[StringName] = [
	&"tile_sets",
	&"tile_variants",
	&"terrain_tiles",
	&"edge_tiles",
	&"void_tiles",
	&"object_scenes",
	&"passage_tiles",
	&"biome_asset_sets"
]
const GENERATED_BY := "generate_isometric_environment_assets"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "asset pipeline manifest loads")
	_expect(manifest.version >= 9, "asset pipeline uses manifest v9")
	_expect(bool(manifest.validate().get("is_valid", false)), "asset pipeline manifest validates")

	_run_directory_structure()
	_run_manifest_filesystem_alignment(manifest)
	_run_sample_svg_metadata(manifest)
	_run_docs_and_tooling()

	_finish()

func _run_directory_structure() -> void:
	for dir_path in REQUIRED_DIRS:
		_expect(
			DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)),
			"%s directory exists" % dir_path
		)

func _run_manifest_filesystem_alignment(manifest: IsometricEnvironmentManifest) -> void:
	var checked := 0
	for section in CONTRACT_SECTIONS:
		for asset_id in manifest.get_asset_contract_ids(section):
			var contract := manifest.get_asset_contract(section, asset_id)
			var asset_path := String(contract.get("asset_path", ""))
			if not asset_path.ends_with(".svg"):
				continue
			checked += 1
			_expect(FileAccess.file_exists(asset_path), "%s/%s asset file exists" % [String(section), String(asset_id)])
			_expect(_is_snake_case_svg(asset_path), "%s/%s uses snake_case svg filename" % [String(section), String(asset_id)])
			_expect(
				String(contract.get("status", "")) != "needs_asset",
				"%s/%s status advanced beyond needs_asset" % [String(section), String(asset_id)]
			)
			_expect(
				not String(contract.get("fallback_path", "")).is_empty(),
				"%s/%s keeps an explicit fallback path" % [String(section), String(asset_id)]
			)
	_expect(checked >= 70, "asset pipeline checks the generated SVG inventory")

func _run_sample_svg_metadata(manifest: IsometricEnvironmentManifest) -> void:
	var samples := [
		manifest.get_asset_contract(&"tile_sets", &"infected_plains"),
		manifest.get_asset_contract(&"terrain_tiles", &"main_road"),
		manifest.get_asset_contract(&"object_scenes", &"ruined_house"),
		manifest.get_asset_contract(&"edge_tiles", &"boundary_fence"),
		manifest.get_asset_contract(&"void_tiles", &"fall_zone"),
		manifest.get_asset_contract(&"passage_tiles", &"bridge"),
		manifest.get_asset_contract(&"biome_asset_sets", &"infected_plains")
	]
	for contract in samples:
		var typed_contract := contract as Dictionary
		var asset_path := String(typed_contract.get("asset_path", ""))
		var asset_id := String(typed_contract.get("id", ""))
		var file := FileAccess.open(asset_path, FileAccess.READ)
		_expect(file != null, "%s sample opens" % asset_path)
		if file == null:
			continue
		var content := file.get_as_text()
		file.close()
		_expect(content.contains('data-generated-by="%s"' % GENERATED_BY), "%s has generator metadata" % asset_path)
		_expect(content.contains('data-id="%s"' % asset_id), "%s has stable asset id metadata" % asset_path)
		_expect(content.contains("<svg"), "%s is an SVG document" % asset_path)

func _run_docs_and_tooling() -> void:
	_expect(FileAccess.file_exists("res://tools/generate_isometric_environment_assets.gd"), "asset generator tool exists")
	var readme := _read_text("res://assets/README.md")
	var attribution := _read_text("res://assets/ATTRIBUTION.md")
	_expect(readme.contains("generate_isometric_environment_assets.gd"), "asset README documents the generator")
	_expect(readme.contains("--dry-run"), "asset README documents dry-run")
	_expect(attribution.contains("Contratto asset ambiente isometrico v7"), "attribution tracks the v7 contract")
	_expect(attribution.contains("Asset ambiente SVG generati"), "attribution tracks generated SVG assets")
	var tool_source := _read_text("res://tools/generate_isometric_environment_assets.gd")
	_expect(tool_source.contains("status == \"final\""), "generator contains final asset overwrite guard")
	_expect(tool_source.contains("--overwrite-generated"), "generator makes overwrite explicit")

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _is_snake_case_svg(asset_path: String) -> bool:
	var filename := asset_path.get_file()
	if not filename.ends_with(".svg"):
		return false
	var stem := filename.trim_suffix(".svg")
	for index in range(stem.length()):
		var code := stem.unicode_at(index)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lower and not is_digit and code != 95:
			return false
	return not stem.is_empty() and not stem.begins_with("_") and not stem.ends_with("_")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_ASSET_PIPELINE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_ASSET_PIPELINE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
