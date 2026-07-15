extends GutTest
## Assets A4 — Pipeline degli asset SVG generati (filesystem, metadata, tooling).
##
## Migra: tests/milestone_10_asset_pipeline_smoke_test.gd
## Verifica la struttura delle cartelle, l'allineamento manifest↔filesystem dei
## contratti SVG, i metadata di provenienza nei sample e la documentazione/tooling.

const REQUIRED_DIRS: Array[String] = [
	"res://assets/environment/top_down/tiles/plains",
	"res://assets/environment/top_down/tiles/toxic",
	"res://assets/environment/top_down/tiles/ash",
	"res://assets/environment/top_down/tiles/snow",
	"res://assets/environment/top_down/tiles/marsh",
	"res://assets/environment/top_down/tiles/forest",
	"res://assets/environment/top_down/tiles/shared",
	"res://assets/environment/top_down/objects/houses",
	"res://assets/environment/top_down/objects/barriers",
	"res://assets/environment/top_down/objects/debris",
	"res://assets/environment/top_down/objects/fences",
	"res://assets/environment/top_down/objects/rocks",
	"res://assets/environment/top_down/objects/trees",
	"res://assets/environment/top_down/objects/vegetation",
	"res://assets/environment/top_down/objects/wrecks",
	"res://assets/environment/top_down/objects/barrels",
	"res://assets/environment/top_down/objects/bridges",
	"res://assets/environment/top_down/objects/crates",
	"res://assets/environment/top_down/objects/generated_props",
	"res://assets/environment/top_down/concepts",
	"res://assets/environment/top_down/edges/cliffs",
	"res://assets/environment/top_down/edges/walls",
	"res://assets/environment/top_down/edges/void",
	"res://assets/environment/top_down/passages",
	"res://assets/environment/top_down/previews"
]
const CONTRACT_SECTIONS: Array[StringName] = [
	&"tile_sets", &"tile_variants", &"terrain_tiles", &"edge_tiles",
	&"void_tiles", &"object_scenes", &"passage_tiles", &"biome_asset_sets"
]
const GENERATED_BY := "generate_top_down_environment_assets"
const GENERATED_PROP_ASSET_IDS: Array[StringName] = [
	&"ruined_house", &"abandoned_car", &"broken_fence", &"wood_barrier",
	&"lab_block", &"lab_ruin", &"pipe_stack", &"toxic_barrel",
	&"chemical_barrel", &"industrial_fence", &"corroded_barrier",
	&"burned_house", &"burned_car", &"charred_wall", &"scorched_barricade",
	&"snow_cabin", &"ice_rock", &"ice_block", &"snow_wall",
	&"sunken_house", &"sunken_wreck", &"dead_tree", &"marsh_log"
]

var _manifest: EnvironmentAssetManifest

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()

func test_manifest_v11_top_down_contract() -> void:
	assert_true(_manifest.load_error.is_empty(), "asset pipeline manifest loads")
	assert_gte(_manifest.version, 11, "asset pipeline uses manifest v11")
	assert_eq(
		_manifest.coordinate_system,
		"orthogonal_top_down",
		"asset pipeline uses the screen-aligned cardinal coordinate contract"
	)
	assert_eq(
		_manifest.volume_style,
		"controlled_perspective",
		"raised props and cliffs keep controlled visual depth"
	)
	assert_true(bool(_manifest.validate().get("is_valid", false)), "asset pipeline manifest validates")

func test_directory_structure() -> void:
	for dir_path in REQUIRED_DIRS:
		assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)), "%s directory exists" % dir_path)

func test_manifest_filesystem_alignment() -> void:
	var checked := 0
	for section in CONTRACT_SECTIONS:
		for asset_id in _manifest.get_asset_contract_ids(section):
			var contract := _manifest.get_asset_contract(section, asset_id)
			var asset_path := String(contract.get("asset_path", ""))
			if not asset_path.ends_with(".svg"):
				continue
			checked += 1
			assert_true(FileAccess.file_exists(asset_path), "%s/%s asset file exists" % [String(section), String(asset_id)])
			assert_true(_is_snake_case_svg(asset_path), "%s/%s uses snake_case svg filename" % [String(section), String(asset_id)])
			assert_ne(String(contract.get("status", "")), "needs_asset", "%s/%s status advanced beyond needs_asset" % [String(section), String(asset_id)])
			assert_false(String(contract.get("fallback_path", "")).is_empty(), "%s/%s keeps an explicit fallback path" % [String(section), String(asset_id)])
	assert_gte(checked, 70, "asset pipeline checks the generated SVG inventory")

func test_sample_svg_metadata() -> void:
	var samples := [
		_manifest.get_asset_contract(&"tile_sets", &"infected_plains"),
		_manifest.get_asset_contract(&"terrain_tiles", &"main_road"),
		_manifest.get_asset_contract(&"object_scenes", &"small_rock"),
		_manifest.get_asset_contract(&"edge_tiles", &"boundary_fence"),
		_manifest.get_asset_contract(&"void_tiles", &"fall_zone"),
		_manifest.get_asset_contract(&"passage_tiles", &"bridge"),
		_manifest.get_asset_contract(&"biome_asset_sets", &"infected_plains")
	]
	for contract in samples:
		var typed_contract := contract as Dictionary
		var asset_path := String(typed_contract.get("asset_path", ""))
		var asset_id := String(typed_contract.get("id", ""))
		var file := FileAccess.open(asset_path, FileAccess.READ)
		assert_not_null(file, "%s sample opens" % asset_path)
		if file == null:
			continue
		var content := file.get_as_text()
		file.close()
		assert_true(content.contains('data-generated-by="%s"' % GENERATED_BY), "%s has generator metadata" % asset_path)
		assert_true(content.contains('data-id="%s"' % asset_id), "%s has stable asset id metadata" % asset_path)
		assert_true(content.contains("<svg"), "%s is an SVG document" % asset_path)

func test_generated_prop_svg_resources() -> void:
	var prop_paths: Dictionary = {}
	for asset_id in GENERATED_PROP_ASSET_IDS:
		var contract := _manifest.get_object_asset_contract(asset_id)
		var asset_path := String(contract.get("asset_path", ""))
		assert_true(
			asset_path.ends_with(".svg"),
			"%s uses an individual SVG resource" % String(asset_id)
		)
		assert_eq(
			String(contract.get("status", "")),
			"final",
			"%s generated prop is final" % String(asset_id)
		)
		assert_eq(
			String(contract.get("source", "")),
			"project_svg_generator",
			"%s records generated provenance" % String(asset_id)
		)
		assert_eq(
			String(contract.get("attribution_key", "")),
			"environment_top_down_internal",
			"%s records generated attribution" % String(asset_id)
		)
		assert_true(
			FileAccess.file_exists(asset_path),
			"%s SVG resource exists" % String(asset_id)
		)
		var file := FileAccess.open(asset_path, FileAccess.READ)
		assert_not_null(file, "%s SVG opens" % String(asset_id))
		if file == null:
			continue
		var content := file.get_as_text()
		file.close()
		assert_true(
			content.contains('data-generated-by="%s"' % GENERATED_BY),
			"%s records the cardinal SVG generator" % String(asset_id)
		)
		assert_true(
			content.contains('data-id="%s"' % String(asset_id)),
			"%s records its stable object id" % String(asset_id)
		)
		assert_false(
			FileAccess.file_exists(asset_path.trim_suffix(".svg") + ".tres"),
			"%s retired AtlasTexture resource is absent" % String(asset_id)
		)
		prop_paths[asset_path] = true
	assert_eq(
		prop_paths.size(),
		GENERATED_PROP_ASSET_IDS.size(),
		"every generated prop has a dedicated cardinal SVG"
	)

func test_docs_and_tooling() -> void:
	assert_true(FileAccess.file_exists("res://tools/generate_top_down_environment_assets.gd"), "asset generator tool exists")
	var readme := _read_text("res://assets/README.md")
	var attribution := _read_text("res://assets/ATTRIBUTION.md")
	assert_true(readme.contains("generate_top_down_environment_assets.gd"), "asset README documents the generator")
	assert_true(readme.contains("--dry-run"), "asset README documents dry-run")
	assert_true(attribution.contains("Contratto asset ambiente top-down"), "attribution tracks the v11 top-down contract")
	assert_true(attribution.contains("Asset ambiente SVG generati"), "attribution tracks generated SVG assets")
	var tool_source := _read_text("res://tools/generate_top_down_environment_assets.gd")
	assert_true(tool_source.contains("status == \"final\""), "generator contains final asset overwrite guard")
	assert_true(tool_source.contains("--overwrite-generated"), "generator makes overwrite explicit")
	assert_true(tool_source.contains("--migrate-projection"), "projection migration requires an explicit overwrite flag")

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
