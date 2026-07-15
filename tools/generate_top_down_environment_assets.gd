extends SceneTree

const GENERATED_BY := "generate_top_down_environment_assets"
const MANIFEST_LOADER_PATH := "res://game/modes/zombie/environment_asset_manifest.gd"
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
	var migrate_projection := args.has("--migrate-projection")
	var only_ids := _parse_only_ids(args)
	if not dry_run and not write and not check:
		dry_run = true

	var manifest_script := load(MANIFEST_LOADER_PATH)
	if manifest_script == null:
		_fail("manifest loader missing: %s" % MANIFEST_LOADER_PATH)
		_finish()
		return
	var manifest = manifest_script.reload_shared()
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
		if not only_ids.is_empty() and not only_ids.has(String(contract.get("id", ""))):
			continue
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
		if not asset_path.ends_with(".svg"):
			if not exists:
				_fail("missing authored texture asset: %s" % asset_path)
			else:
				skipped_final += 1
			continue
		if exists and (not overwrite or (status == "final" and not migrate_projection)):
			if status == "final":
				skipped_final += 1
			else:
				skipped_existing += 1
			continue
		if dry_run:
			print("DRY-RUN: would generate ", asset_path)
			continue
		if status == "final" and not migrate_projection:
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
		print("TOP_DOWN_ASSET_GENERATOR: DRY-RUN targets=%d unique=%d" % [planned.size(), seen_paths.size()])
	elif check:
		print("TOP_DOWN_ASSET_GENERATOR: CHECK checked=%d" % checked)
	else:
		print(
			"TOP_DOWN_ASSET_GENERATOR: WRITE created=%d skipped_existing=%d skipped_final=%d"
			% [created, skipped_existing, skipped_final]
		)
	_finish()

# --only=id1,id2 limits write/overwrite passes to specific contract ids so a
# template fix can regenerate one asset family without touching the rest.
func _parse_only_ids(args: PackedStringArray) -> Dictionary:
	var only_ids: Dictionary = {}
	for arg in args:
		if not arg.begins_with("--only="):
			continue
		for raw_id in arg.trim_prefix("--only=").split(",", false):
			only_ids[raw_id.strip_edges()] = true
	return only_ids

func _collect_asset_targets(manifest) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section in ASSET_SECTIONS:
		for asset_id in manifest.get_asset_contract_ids(section):
			var contract: Dictionary = manifest.get_asset_contract(section, asset_id)
			var asset_path := String(contract.get("asset_path", ""))
			if asset_path.ends_with(".svg"):
				result.append(contract)
			elif (
				asset_path.ends_with(".png")
				or asset_path.ends_with(".webp")
				or asset_path.ends_with(".tres")
			):
				result.append(contract)
			elif not asset_path.is_empty():
				_fail("%s/%s asset_path has an unsupported format: %s" % [String(section), String(asset_id), asset_path])
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
	var shape := _section_shape(section, asset_id, primary, secondary, accent)
	var native_size := _native_svg_size(contract)
	var footprint := contract.get("footprint_slots", Vector2i.ONE) as Vector2i
	# Tall canvases (e.g. reed_wall 56x136) letterbox a 160x120 viewBox down to a
	# tiny strip; stretching the viewBox instead lets the art fill the native
	# visual box, and the shape is drawn to survive the anisotropic scale.
	var aspect_attribute := (
		' preserveAspectRatio="none"' if _uses_stretch_canvas(asset_id) else ""
	)
	var lines := PackedStringArray([
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 160 120"%s data-generated-by="%s" data-section="%s" data-id="%s" data-footprint-slots="%dx%d">' % [native_size.x, native_size.y, aspect_attribute, GENERATED_BY, _xml_escape(section), _xml_escape(asset_id), footprint.x, footprint.y],
		'  <title>%s</title>' % _xml_escape(title),
		'  <ellipse cx="80" cy="94" rx="54" ry="13" fill="#050608" opacity="0.38"/>',
		shape
	])
	# A small screen-aligned accent is loot-crate language. It must never become
	# an embedded floor or imply an inclined world axis.
	if not _is_building_asset(section, asset_id) and not _uses_stretch_canvas(asset_id):
		lines.append('  <path d="M48 108 H112" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.62"/>' % accent)
	lines.append('</svg>')
	lines.append("")
	return "\n".join(lines)

func _uses_stretch_canvas(asset_id: String) -> bool:
	return asset_id == "reed_wall"

func _is_building_asset(section: String, asset_id: String) -> bool:
	return (
		section == "object_scenes"
		and (
			asset_id.contains("house")
			or asset_id.contains("cabin")
			or asset_id.contains("lab_block")
			or asset_id.contains("lab_ruin")
		)
	)

func _section_shape(section: String, asset_id: String, primary: String, secondary: String, accent: String) -> String:
	match section:
		"tile_sets", "tile_variants", "terrain_tiles", "passage_tiles":
			return _terrain_tile_shape(asset_id, primary, secondary, accent)
		"edge_tiles":
			return "\n".join(PackedStringArray([
				'  <rect x="18" y="22" width="124" height="64" rx="3" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
				'  <path d="M18 86 H142 L134 105 H26 Z" fill="%s" stroke="#101010" stroke-width="3"/>' % secondary,
				'  <path d="M28 36 H132 M28 54 H132 M28 72 H132" stroke="%s" stroke-width="3" opacity="0.58"/>' % accent
			]))
		"void_tiles":
			return _void_tile_shape(asset_id, primary, secondary, accent)
		"object_scenes":
			return _object_scene_shape(asset_id, primary, secondary, accent)
		"biome_asset_sets":
			return "\n".join(PackedStringArray([
				'  <rect x="14" y="16" width="132" height="88" rx="5" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
				'  <circle cx="80" cy="60" r="20" fill="%s" stroke="#0b0b0b" stroke-width="4"/>' % secondary,
				'  <path d="M38 60 H122 M80 24 V96" stroke="%s" stroke-width="4" opacity="0.75"/>' % accent
			]))
		_:
			return '  <rect x="18" y="16" width="124" height="88" rx="4" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent]

func _void_tile_shape(
	asset_id: String,
	primary: String,
	secondary: String,
	accent: String
) -> String:
	var base := PackedStringArray([
		'  <rect x="16" y="14" width="128" height="80" fill="%s" stroke="#101722" stroke-width="3"/>' % primary,
		'  <path d="M16 94 H144 L136 112 H24 Z" fill="#05070b" stroke="%s" stroke-width="2"/>' % secondary,
		'  <path d="M38 96 L36 108 M60 96 L59 111 M82 96 L82 112 M104 96 L103 111 M126 96 L124 108" stroke="%s" stroke-width="3" opacity="0.72"/>' % secondary,
		'  <path d="M20 104 C43 97 58 110 80 103 C101 96 119 108 140 101" fill="none" stroke="%s" stroke-width="4" opacity="0.28"/>' % accent
	])
	var lip_paths: PackedStringArray = _void_lip_paths(asset_id)
	for lip_path in lip_paths:
		base.append(
			'  <path d="%s" fill="none" stroke="%s" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
			% [lip_path, accent]
		)
		base.append(
			'  <path d="%s" transform="translate(0 7)" fill="none" stroke="#020305" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" opacity="0.82"/>'
			% lip_path
		)
	return "\n".join(base)

func _void_lip_paths(asset_id: String) -> PackedStringArray:
	if asset_id.ends_with("edge_north"):
		return PackedStringArray(["M16 14 H144"])
	if asset_id.ends_with("edge_south"):
		return PackedStringArray(["M16 94 H144"])
	if asset_id.ends_with("edge_east"):
		return PackedStringArray(["M144 14 V94"])
	if asset_id.ends_with("edge_west"):
		return PackedStringArray(["M16 14 V94"])
	if asset_id.ends_with("inner_north_east"):
		return PackedStringArray(["M16 14 H144 V94"])
	if asset_id.ends_with("inner_south_east"):
		return PackedStringArray(["M144 14 V94 H16"])
	if asset_id.ends_with("inner_south_west"):
		return PackedStringArray(["M144 94 H16 V14"])
	if asset_id.ends_with("inner_north_west"):
		return PackedStringArray(["M16 94 V14 H144"])
	if asset_id.ends_with("outer_north_east"):
		return PackedStringArray(["M16 14 H144", "M144 14 V94"])
	if asset_id.ends_with("outer_south_east"):
		return PackedStringArray(["M144 14 V94", "M144 94 H16"])
	if asset_id.ends_with("outer_south_west"):
		return PackedStringArray(["M144 94 H16", "M16 94 V14"])
	if asset_id.ends_with("outer_north_west"):
		return PackedStringArray(["M16 94 V14", "M16 14 H144"])
	if asset_id.ends_with("north_east_south_west"):
		return PackedStringArray(["M16 54 H144"])
	if asset_id.ends_with("north_west_south_east"):
		return PackedStringArray(["M80 14 V94"])
	return PackedStringArray(["M16 14 H144"])

func _terrain_tile_shape(asset_id: String, primary: String, secondary: String, accent: String) -> String:
	var base := PackedStringArray([
		'  <rect x="12" y="12" width="136" height="96" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
		'  <rect x="26" y="24" width="108" height="72" fill="none" stroke="%s" stroke-width="3" opacity="0.42"/>' % secondary
	])
	if asset_id.contains("intersection"):
		base.append('  <path d="M22 60 H138 M80 18 V102" stroke="%s" stroke-width="11" stroke-linecap="square" opacity="0.72"/>' % accent)
	elif asset_id.contains("curve"):
		base.append('  <path d="M22 60 H66 Q80 60 80 46 V18" fill="none" stroke="%s" stroke-width="11" stroke-linecap="square" opacity="0.72"/>' % accent)
	elif asset_id.contains("entry") or asset_id.contains("exit"):
		base.append('  <path d="M18 60 H142" fill="none" stroke="%s" stroke-width="11" stroke-linecap="square" opacity="0.72"/>' % accent)
		base.append('  <path d="M75 45 H85 V55 H95 V65 H85 V75 H75 V65 H65 V55 H75 Z" fill="%s" opacity="0.85"/>' % secondary)
	elif _asset_is_route(asset_id):
		base.append('  <path d="M12 60 H148" stroke="%s" stroke-width="14" stroke-linecap="square" opacity="0.70"/>' % accent)
		base.append('  <path d="M22 60 H138" stroke="%s" stroke-width="4" stroke-linecap="square" opacity="0.38"/>' % secondary)
	else:
		base.append('  <path d="M30 60 H130" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.38"/>' % accent)
	return "\n".join(base)

func _object_scene_shape(asset_id: String, primary: String, secondary: String, accent: String) -> String:
	if asset_id.contains("house") or asset_id.contains("cabin") or asset_id.contains("lab_block") or asset_id.contains("lab_ruin"):
		return _building_shape(asset_id, primary, secondary, accent)
	if asset_id.contains("barrel"):
		return _barrel_shape(asset_id, primary, accent)
	if asset_id.contains("car") or asset_id.contains("wreck"):
		return _wreck_shape(asset_id, primary, secondary, accent)
	if asset_id.contains("tree"):
		return _dead_tree_shape(primary, accent)
	if asset_id.contains("log"):
		return _log_shape(primary, accent)
	if asset_id.contains("bridge") or asset_id.contains("walkway"):
		return _bridge_object_shape(primary, secondary, accent)
	if asset_id.contains("dense_vegetation") or asset_id.contains("forest"):
		return _dense_vegetation_shape(primary, secondary, accent)
	if asset_id.contains("debris"):
		return _debris_shape(primary, secondary, accent)
	if asset_id.contains("pipe"):
		return _barrier_shape(asset_id, primary, secondary, accent)
	if asset_id.contains("rock") or asset_id.contains("ice_block"):
		return _rock_shape(asset_id, primary, accent)
	if asset_id.contains("reed"):
		return _reed_wall_shape(primary, accent)
	if (
		asset_id.contains("fence")
		or asset_id.contains("wall")
		or asset_id.contains("barrier")
		or asset_id.contains("barricade")
	):
		return _barrier_shape(asset_id, primary, secondary, accent)
	if asset_id.contains("crate"):
		return _crate_shape(primary, secondary, accent)
	return _rock_shape(asset_id, primary, accent)

func _native_svg_size(contract: Dictionary) -> Vector2i:
	if String(contract.get("section", "")) != "object_scenes":
		return Vector2i(160, 120)
	var footprint := contract.get("footprint_tiles", Vector2i.ONE) as Vector2i
	var visual_height := int(contract.get("visual_height_tiles", 0))
	return Vector2i(
		maxi(roundi(float(footprint.x) * 8.0 * 1.55), 56),
		maxi((footprint.y + visual_height) * 8, 56)
	)

# Buildings use a screen-aligned roof and a controlled south facade. Their
# footprint stays rectangular; depth is visual and never changes collision.
func _building_shape(asset_id: String, primary: String, _secondary: String, accent: String) -> String:
	var wall_light := _shade(primary, -0.08)
	var wall_dark := _shade(primary, -0.30)
	var roof := _shade(primary, -0.48)
	var roof_hi := _shade(primary, -0.20)
	var foundation := _shade(primary, -0.62)
	var lines := PackedStringArray([
		'  <rect x="34" y="26" width="92" height="70" rx="2" fill="%s" opacity="0.95"/>' % foundation,
		'  <path d="M40 56 H120 V94 H40 Z" fill="%s" stroke="#0b0c0d" stroke-width="2"/>' % wall_light,
		'  <path d="M120 56 L126 61 V90 L120 94 Z" fill="%s" stroke="#0b0c0d" stroke-width="2"/>' % wall_dark,
		'  <path d="M44 68 H116 M44 78 H116" stroke="#000000" stroke-width="2" opacity="0.16"/>',
		'  <rect x="34" y="18" width="92" height="48" rx="3" fill="%s" stroke="#0b0c0d" stroke-width="3"/>' % roof,
		'  <rect x="44" y="27" width="72" height="30" fill="none" stroke="%s" stroke-width="2" opacity="0.5"/>' % roof_hi,
		'  <path d="M36 64 H124" fill="none" stroke="#000000" stroke-width="4" opacity="0.25"/>',
		'  <rect x="55" y="72" width="16" height="22" fill="#0a0c0c" stroke="%s" stroke-width="2" stroke-opacity="0.28"/>' % accent,
		'  <rect x="91" y="70" width="18" height="12" fill="#0d1315" stroke="%s" stroke-width="2" stroke-opacity="0.30"/>' % accent
	])
	if asset_id.contains("ruin") or asset_id.contains("ruined"):
		lines.append('  <path d="M58 18 H88 V39 H70 V52 H48 V34 H58 Z" fill="#0a0c0c" opacity="0.92"/>')
		lines.append('  <path d="M38 44 L52 28 L66 38 L80 22 L96 36 L112 28 L123 42" fill="none" stroke="#0d0d0d" stroke-width="5" stroke-linecap="round"/>')
		lines.append('  <path d="M52 60 L60 74 M100 52 L108 66" stroke="#050505" stroke-width="3" stroke-linecap="round"/>')
	elif asset_id.contains("burn"):
		lines.append('  <path d="M44 42 L56 28 L66 40 L76 24 L88 42 L100 27 L114 40" fill="none" stroke="#090706" stroke-width="5" stroke-linecap="round"/>')
		lines.append('  <path d="M58 60 L62 50 M96 56 L100 47" stroke="#090706" stroke-width="4" stroke-linecap="round" opacity="0.7"/>')
		lines.append('  <path d="M54 72 L104 52" stroke="#1b0e0a" stroke-width="4" stroke-linecap="round" opacity="0.8"/>')
	elif asset_id.contains("snow") or asset_id.contains("cabin"):
		lines.append('  <path d="M36 20 H124" fill="none" stroke="#edf8fb" stroke-width="6" stroke-linecap="round"/>')
		lines.append('  <path d="M48 54 C66 60 94 60 112 54" fill="none" stroke="#edf8fb" stroke-width="4" opacity="0.8"/>')
	elif asset_id.contains("sunken"):
		lines.append('  <path d="M42 80 C56 74 68 88 80 90 C94 86 108 74 118 70" fill="none" stroke="#7fc0a6" stroke-width="4" opacity="0.7"/>')
		lines.append('  <path d="M46 86 C60 81 72 92 84 93 C96 90 108 80 116 76" fill="none" stroke="#7fc0a6" stroke-width="3" opacity="0.4"/>')
		lines.append('  <path d="M50 84 L54 90 M88 84 L92 90" stroke="#2c4a42" stroke-width="3" stroke-linecap="round"/>')
	elif asset_id.contains("lab"):
		lines.append('  <rect x="58" y="28" width="16" height="10" fill="%s" stroke="#0b0c0d" stroke-width="2"/>' % wall_light)
		lines.append('  <rect x="88" y="24" width="16" height="10" fill="%s" stroke="#0b0c0d" stroke-width="2"/>' % wall_light)
		lines.append('  <path d="M40 48 H120" fill="none" stroke="%s" stroke-width="2" opacity="0.45"/>' % accent)
		lines.append('  <circle cx="108" cy="52" r="3" fill="%s" opacity="0.75"/>' % accent)
	else:
		lines.append('  <path d="M90 70 H110 M90 77 H110" stroke="#2a2118" stroke-width="3" stroke-linecap="round"/>')
		lines.append('  <path d="M46 40 H114" fill="none" stroke="#000000" stroke-width="3" opacity="0.25"/>')
	return "\n".join(lines)

# Derives a muted tone from a template colour: negative factors darken toward
# black, positive factors lighten toward white.
func _shade(hex: String, factor: float) -> String:
	var color := Color(hex)
	color = color.darkened(-factor) if factor < 0.0 else color.lightened(factor)
	return "#" + color.to_html(false)

func _barrier_shape(asset_id: String, primary: String, secondary: String, accent: String) -> String:
	var lines := PackedStringArray([
		'  <rect x="26" y="72" width="108" height="28" rx="3" fill="%s" stroke="%s" stroke-width="3"/>' % [secondary, accent]
	])
	if asset_id.contains("fence"):
		for x in [42, 58, 76, 96, 114]:
			lines.append('  <path d="M%d 88 V42" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % [x, primary])
		lines.append('  <path d="M34 58 H126 M34 76 H126" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % accent)
	elif asset_id.contains("pipe"):
		for y in [52, 66, 80]:
			lines.append('  <path d="M36 %d H116" stroke="%s" stroke-width="12" stroke-linecap="round"/>' % [y, primary])
			lines.append('  <ellipse cx="118" cy="%d" rx="8" ry="5" fill="%s" stroke="%s" stroke-width="2"/>' % [y, secondary, accent])
	elif asset_id.contains("wall") or asset_id.contains("boundary"):
		lines.append('  <rect x="34" y="48" width="92" height="40" fill="%s" stroke="#0b0b0b" stroke-width="4"/>' % primary)
		lines.append('  <path d="M48 52 V84 M68 52 V84 M88 52 V84 M108 52 V84" stroke="%s" stroke-width="3" opacity="0.82"/>' % accent)
	else:
		lines.append('  <rect x="34" y="54" width="94" height="28" rx="3" fill="%s" stroke="#0b0b0b" stroke-width="4"/>' % primary)
		lines.append('  <path d="M45 62 H116 M63 76 H101" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent)
	return "\n".join(lines)

func _barrel_shape(asset_id: String, primary: String, accent: String) -> String:
	var symbol := (
		'  <path d="M74 58 L86 58 M80 52 L80 64" stroke="#0b0b0b" stroke-width="3" stroke-linecap="round"/>'
		if asset_id.contains("toxic") or asset_id.contains("chemical")
		else '  <path d="M68 60 L92 60" stroke="#0b0b0b" stroke-width="3" stroke-linecap="round"/>'
	)
	return "\n".join(PackedStringArray([
		'  <ellipse cx="80" cy="80" rx="24" ry="9" fill="%s" stroke="%s" stroke-width="3"/>' % [primary, accent],
		'  <path d="M56 48 C56 38 104 38 104 48 L104 80 C104 91 56 91 56 80 Z" fill="%s" stroke="#0a0a0a" stroke-width="4"/>' % primary,
		'  <ellipse cx="80" cy="48" rx="24" ry="9" fill="%s" stroke="%s" stroke-width="3"/>' % [primary, accent],
		'  <path d="M58 61 C70 69 90 69 102 61 M58 73 C70 81 90 81 102 73" stroke="%s" stroke-width="4" opacity="0.82"/>' % accent,
		symbol
	]))

func _wreck_shape(
	asset_id: String,
	primary: String,
	secondary: String,
	accent: String
) -> String:
	var lines := PackedStringArray([
		'  <rect x="44" y="27" width="20" height="10" rx="4" fill="#050607"/>',
		'  <rect x="98" y="27" width="20" height="10" rx="4" fill="#050607"/>',
		'  <rect x="44" y="83" width="20" height="10" rx="4" fill="#050607"/>',
		'  <rect x="98" y="83" width="20" height="10" rx="4" fill="#050607"/>',
		'  <path d="M46 34 H112 L128 49 V80 L114 91 H46 L33 80 V49 Z" fill="%s" stroke="#090909" stroke-width="4"/>' % primary,
		'  <rect x="57" y="43" width="49" height="36" rx="7" fill="#101619" stroke="%s" stroke-width="3"/>' % accent,
		'  <path d="M65 45 V77 M98 45 V77 M57 61 H106" stroke="%s" stroke-width="3" opacity="0.62"/>' % secondary,
		'  <path d="M35 79 H126 L114 96 H48 Z" fill="%s" stroke="#090909" stroke-width="3"/>' % _shade(primary, -0.28),
		'  <path d="M48 88 H113" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.72"/>' % accent
	])
	if asset_id.contains("burn"):
		lines.append('  <path d="M52 40 L78 58 L60 75 M92 42 L76 61 L101 80" fill="none" stroke="#160d09" stroke-width="5" stroke-linecap="round" opacity="0.86"/>')
	elif asset_id.contains("sunken"):
		lines.append('  <path d="M38 72 C55 66 68 82 82 78 C98 73 111 64 124 69" fill="none" stroke="#7fc0a6" stroke-width="5" opacity="0.68"/>')
	else:
		lines.append('  <path d="M38 53 H51 M111 53 H124" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % accent)
	return "\n".join(lines)

func _rock_shape(asset_id: String, primary: String, accent: String) -> String:
	var highlight := "#d6edf3" if asset_id.contains("ice") else accent
	return "\n".join(PackedStringArray([
		'  <path d="M40 68 L55 42 L88 31 L122 48 L130 76 L109 96 H67 L38 83 Z" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
		'  <path d="M55 42 L88 31 L102 51 L80 67 L40 68 Z" fill="%s" opacity="0.45"/>' % highlight,
		'  <path d="M80 67 L109 96 M80 67 L130 76 M67 96 L80 67" stroke="#0b0b0b" stroke-width="2" opacity="0.45"/>'
	]))

func _dense_vegetation_shape(primary: String, secondary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <rect x="22" y="70" width="116" height="36" rx="14" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
		'  <path d="M42 85 L47 47 M64 88 L66 35 M87 91 L86 29 M110 87 L111 42 M126 84 L128 58" stroke="#252016" stroke-width="8" stroke-linecap="round"/>',
		'  <circle cx="34" cy="59" r="23" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="57" cy="43" r="27" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="84" cy="37" r="30" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="109" cy="48" r="27" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="130" cy="64" r="22" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="70" cy="68" r="28" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="103" cy="70" r="27" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <path d="M22 84 C36 67 50 74 62 65 C75 55 87 72 99 63 C113 53 128 70 139 83 L132 101 H28 Z" fill="%s" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % [primary, accent]
	]))

func _debris_shape(primary: String, secondary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <rect x="32" y="55" width="98" height="45" rx="10" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
		'  <path d="M43 73 L64 48 L91 67 L119 56 L128 79 L96 91 L72 83 L50 94 Z" fill="%s" stroke="#0b0d0e" stroke-width="4"/>' % primary,
		'  <path d="M56 67 L106 85 M80 54 L72 88 M101 62 L114 77" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent
	]))

func _dead_tree_shape(primary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <ellipse cx="80" cy="68" rx="24" ry="18" fill="%s" opacity="0.76"/>' % primary,
		'  <path d="M82 104 C80 88 81 73 80 62 C79 46 78 32 78 18" stroke="%s" stroke-width="16" stroke-linecap="round" fill="none"/>' % primary,
		'  <path d="M80 62 L45 36 M80 62 L121 39 M81 76 L45 92 M81 76 L118 96" stroke="%s" stroke-width="12" stroke-linecap="round" fill="none"/>' % primary,
		'  <path d="M45 36 L32 24 M121 39 L136 27 M45 92 L29 103 M118 96 L133 108 M78 25 L68 12" stroke="%s" stroke-width="6" stroke-linecap="round" fill="none"/>' % accent,
		'  <ellipse cx="82" cy="104" rx="14" ry="8" fill="%s" stroke="#0b0b0b" stroke-width="3"/>' % primary
	]))

func _log_shape(primary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <path d="M38 58 H122 C134 58 134 82 122 82 H38 C26 82 26 58 38 58 Z" fill="%s" stroke="#090909" stroke-width="4"/>' % primary,
		'  <ellipse cx="38" cy="70" rx="12" ry="12" fill="%s" stroke="%s" stroke-width="3"/>' % [primary, accent],
		'  <path d="M52 66 H118 M76 60 V80 M100 60 V80" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % accent
	]))

func _bridge_object_shape(primary: String, secondary: String, accent: String) -> String:
	var lines := PackedStringArray([
		'  <rect x="24" y="42" width="112" height="60" fill="%s" stroke="%s" stroke-width="3"/>' % [secondary, accent]
	])
	for index in range(6):
		var x_a := 39 + index * 15
		lines.append('  <path d="M%d 48 V96" stroke="%s" stroke-width="8" stroke-linecap="round"/>' % [x_a, primary])
	lines.append('  <path d="M30 50 H130 M30 94 H130" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent)
	return "\n".join(lines)

# Canneto verticale per reed_wall: disegnato nel viewBox 160x120 ma reso con
# preserveAspectRatio="none" su canvas 56x136, quindi gli steli larghi ~7 unita'
# diventano canne sottili e alte. Niente lastre/pali da barriera generica.
func _reed_wall_shape(primary: String, accent: String) -> String:
	var lines := PackedStringArray([
		'  <ellipse cx="80" cy="100" rx="56" ry="11" fill="%s" opacity="0.78"/>' % _shade(primary, -0.5)
	])
	var stem_tops: Array[int] = [26, 14, 20, 10, 18, 12, 22, 16, 28]
	for index in range(stem_tops.size()):
		var x := 26 + index * 14
		var lean := (index % 3) - 1
		lines.append(
			'  <path d="M%d 104 C%d 70 %d 45 %d %d" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>'
			% [x, x + lean * 3, x + lean * 5, x + lean * 7, stem_tops[index], _shade(primary, -0.06 - 0.05 * float(index % 2))]
		)
	for index: int in [1, 3, 5, 7]:
		var x: int = 26 + index * 14
		var lean: int = (index % 3) - 1
		lines.append(
			'  <ellipse cx="%d" cy="%d" rx="7" ry="11" fill="#5c4327" stroke="#241a10" stroke-width="2"/>'
			% [x + lean * 7, stem_tops[index] + 6]
		)
	lines.append('  <path d="M40 96 L58 60 M96 98 L112 66 M68 100 L60 74" fill="none" stroke="%s" stroke-width="4" stroke-linecap="round" opacity="0.55"/>' % accent)
	return "\n".join(lines)

func _crate_shape(primary: String, secondary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <rect x="50" y="48" width="60" height="38" fill="%s" stroke="%s" stroke-width="3"/>' % [secondary, accent],
		'  <path d="M50 86 H110 L104 104 H56 Z" fill="%s" stroke="#0b0b0b" stroke-width="3"/>' % primary,
		'  <path d="M58 55 H102 M80 50 V102 M58 96 H102" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % accent
	]))

func _asset_is_route(asset_id: String) -> bool:
	return (
		asset_id.contains("road")
		or asset_id.contains("lane")
		or asset_id.contains("street")
		or asset_id.contains("path")
		or asset_id.contains("walkway")
		or asset_id.contains("bridge")
		or asset_id.contains("pass")
		or asset_id.contains("gate")
	)

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
