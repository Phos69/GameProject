extends SceneTree

const GENERATED_BY := "generate_isometric_environment_assets"
const ASSET_SECTIONS: Array[StringName] = [
	&"tile_sets",
	&"tile_variants",
	&"terrain_tiles",
	&"edge_tiles",
	&"void_tiles",
	&"object_scenes",
	&"passage_tiles",
	&"biome_asset_sets"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dry_run := args.has("--dry-run")
	var write := args.has("--write")
	var check := args.has("--check")
	var overwrite := args.has("--overwrite-generated")
	if not dry_run and not write and not check:
		dry_run = true

	var manifest := IsometricEnvironmentManifest.reload_shared()
	if not manifest.load_error.is_empty():
		_fail("manifest load failed: %s" % manifest.load_error)
		_finish()
		return

	var planned := _collect_asset_targets(manifest)
	var created := 0
	var skipped_existing := 0
	var skipped_final := 0
	var checked := 0
	var seen_paths: Dictionary = {}

	for target in planned:
		var contract := target as Dictionary
		var asset_path := String(contract.get("asset_path", ""))
		if seen_paths.has(asset_path):
			continue
		seen_paths[asset_path] = true
		var absolute_path := ProjectSettings.globalize_path(asset_path)
		var exists := FileAccess.file_exists(absolute_path)
		var status := String(contract.get("status", ""))
		if check:
			checked += 1
			if not exists:
				_fail("missing generated asset: %s" % asset_path)
			continue
		if exists and (not overwrite or status == "final"):
			if status == "final":
				skipped_final += 1
			else:
				skipped_existing += 1
			continue
		if dry_run:
			print("DRY-RUN: would generate ", asset_path)
			continue
		if status == "final":
			skipped_final += 1
			continue
		_ensure_parent_dir(absolute_path)
		var file := FileAccess.open(absolute_path, FileAccess.WRITE)
		if file == null:
			_fail("cannot write asset: %s" % asset_path)
			continue
		file.store_string(_build_svg(contract))
		file.close()
		created += 1

	if dry_run:
		print("ISOMETRIC_ASSET_GENERATOR: DRY-RUN targets=%d unique=%d" % [planned.size(), seen_paths.size()])
	elif check:
		print("ISOMETRIC_ASSET_GENERATOR: CHECK checked=%d" % checked)
	else:
		print(
			"ISOMETRIC_ASSET_GENERATOR: WRITE created=%d skipped_existing=%d skipped_final=%d"
			% [created, skipped_existing, skipped_final]
		)
	_finish()

func _collect_asset_targets(manifest: IsometricEnvironmentManifest) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section in ASSET_SECTIONS:
		for asset_id in manifest.get_asset_contract_ids(section):
			var contract := manifest.get_asset_contract(section, asset_id)
			var asset_path := String(contract.get("asset_path", ""))
			if asset_path.ends_with(".svg"):
				result.append(contract)
			elif not asset_path.is_empty():
				_fail("%s/%s asset_path is not an SVG: %s" % [String(section), String(asset_id), asset_path])
	return result

func _ensure_parent_dir(absolute_path: String) -> void:
	var parent := absolute_path.get_base_dir()
	if DirAccess.dir_exists_absolute(parent):
		return
	var error := DirAccess.make_dir_recursive_absolute(parent)
	if error != OK:
		_fail("cannot create directory %s (error %d)" % [parent, error])

func _build_svg(contract: Dictionary) -> String:
	var section := String(contract.get("section", "asset"))
	var asset_id := String(contract.get("id", "asset"))
	var primary := _resolve_primary_color(contract)
	var secondary := _resolve_secondary_color(section)
	var accent := _resolve_accent_color(contract)
	var title := "%s %s" % [section, asset_id]
	var shape := _section_shape(section, primary, secondary, accent)
	var lines := PackedStringArray([
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<svg xmlns="http://www.w3.org/2000/svg" width="160" height="120" viewBox="0 0 160 120" data-generated-by="%s" data-section="%s" data-id="%s">' % [GENERATED_BY, _xml_escape(section), _xml_escape(asset_id)],
		'  <title>%s</title>' % _xml_escape(title),
		'  <rect width="160" height="120" fill="#11151a"/>',
		'  <ellipse cx="80" cy="82" rx="58" ry="18" fill="#050608" opacity="0.45"/>',
		shape,
		'  <path d="M24 92 L80 110 L136 92" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.75"/>' % accent,
		'  <path d="M36 96 L80 108 L124 96" fill="none" stroke="#000000" stroke-width="2" opacity="0.35"/>',
		'</svg>',
		""
	])
	return "\n".join(lines)

func _section_shape(section: String, primary: String, secondary: String, accent: String) -> String:
	match section:
		"tile_sets", "tile_variants", "terrain_tiles", "passage_tiles":
			return "\n".join(PackedStringArray([
				'  <polygon points="80,18 142,54 80,90 18,54" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
				'  <path d="M32 54 L80 29 L128 54 L80 79 Z" fill="none" stroke="%s" stroke-width="3" opacity="0.55"/>' % secondary,
				'  <path d="M42 61 L118 61" stroke="%s" stroke-width="5" stroke-linecap="round" opacity="0.65"/>' % accent
			]))
		"edge_tiles":
			return "\n".join(PackedStringArray([
				'  <polygon points="20,58 80,28 140,58 80,88" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
				'  <rect x="36" y="42" width="88" height="34" rx="4" fill="%s" stroke="#101010" stroke-width="4"/>' % primary,
				'  <path d="M42 50 H118 M42 64 H118" stroke="%s" stroke-width="3" opacity="0.7"/>' % accent
			]))
		"void_tiles":
			return "\n".join(PackedStringArray([
				'  <polygon points="20,46 80,18 140,46 80,74" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
				'  <path d="M28 52 L80 80 L132 52 L132 84 L80 112 L28 84 Z" fill="#05070b" stroke="%s" stroke-width="3"/>' % accent,
				'  <path d="M48 60 V94 M80 74 V108 M112 60 V94" stroke="%s" stroke-width="3" opacity="0.75"/>' % secondary
			]))
		"object_scenes":
			return "\n".join(PackedStringArray([
				'  <polygon points="40,72 80,50 120,72 80,94" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
				'  <path d="M54 68 L54 38 L80 24 L106 38 L106 68 L80 84 Z" fill="%s" stroke="#090909" stroke-width="4"/>' % primary,
				'  <path d="M60 42 L80 31 L100 42 M66 58 H94" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent
			]))
		"biome_asset_sets":
			return "\n".join(PackedStringArray([
				'  <polygon points="80,14 146,50 80,86 14,50" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
				'  <circle cx="80" cy="50" r="20" fill="%s" stroke="#0b0b0b" stroke-width="4"/>' % secondary,
				'  <path d="M47 51 H113 M80 23 V78" stroke="%s" stroke-width="4" opacity="0.75"/>' % accent
			]))
		_:
			return '  <polygon points="80,18 142,54 80,90 18,54" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent]

func _resolve_primary_color(contract: Dictionary) -> String:
	var asset_id := String(contract.get("id", ""))
	var biome_ids := contract.get("biome_ids", []) as Array
	var hint := asset_id
	if not biome_ids.is_empty():
		hint += " " + String(biome_ids.front())
	if hint.contains("toxic"):
		return "#2e7d60"
	if hint.contains("burn") or hint.contains("ash") or hint.contains("lava"):
		return "#7a3c2c"
	if hint.contains("snow") or hint.contains("ice") or hint.contains("frozen"):
		return "#7f99a8"
	if hint.contains("marsh") or hint.contains("water") or hint.contains("drowned"):
		return "#355d59"
	if hint.contains("void") or hint.contains("fall") or hint.contains("cliff"):
		return "#1b2230"
	return "#4d5b46"

func _resolve_secondary_color(section: String) -> String:
	match section:
		"edge_tiles":
			return "#2c3235"
		"void_tiles":
			return "#394056"
		"object_scenes":
			return "#242a2f"
		"passage_tiles":
			return "#6b5f42"
		_:
			return "#334038"

func _resolve_accent_color(contract: Dictionary) -> String:
	var asset_id := String(contract.get("id", ""))
	if asset_id.contains("toxic"):
		return "#6fe0a5"
	if asset_id.contains("burn") or asset_id.contains("ash") or asset_id.contains("lava"):
		return "#f08a48"
	if asset_id.contains("snow") or asset_id.contains("ice"):
		return "#d6edf3"
	if asset_id.contains("marsh") or asset_id.contains("water") or asset_id.contains("drowned"):
		return "#7fc0a6"
	if asset_id.contains("void") or asset_id.contains("fall") or asset_id.contains("cliff"):
		return "#6d86b8"
	return "#c2b071"

func _xml_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		quit(0)
		return
	quit(1)
