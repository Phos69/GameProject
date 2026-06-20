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
	var shape := _section_shape(section, asset_id, primary, secondary, accent)
	var native_size := _native_svg_size(contract)
	var footprint := contract.get("footprint_slots", Vector2i.ONE) as Vector2i
	var lines := PackedStringArray([
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 160 120" data-generated-by="%s" data-section="%s" data-id="%s" data-footprint-slots="%dx%d">' % [native_size.x, native_size.y, GENERATED_BY, _xml_escape(section), _xml_escape(asset_id), footprint.x, footprint.y],
		'  <title>%s</title>' % _xml_escape(title),
		'  <ellipse cx="80" cy="82" rx="58" ry="18" fill="#050608" opacity="0.45"/>',
		shape,
		'  <path d="M24 92 L80 110 L136 92" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.75"/>' % accent,
		'  <path d="M36 96 L80 108 L124 96" fill="none" stroke="#000000" stroke-width="2" opacity="0.35"/>',
		'</svg>',
		""
	])
	return "\n".join(lines)

func _section_shape(section: String, asset_id: String, primary: String, secondary: String, accent: String) -> String:
	match section:
		"tile_sets", "tile_variants", "terrain_tiles", "passage_tiles":
			return _terrain_tile_shape(asset_id, primary, secondary, accent)
		"edge_tiles":
			return "\n".join(PackedStringArray([
				'  <polygon points="20,58 80,28 140,58 80,88" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
				'  <rect x="36" y="42" width="88" height="34" rx="4" fill="%s" stroke="#101010" stroke-width="4"/>' % primary,
				'  <path d="M42 50 H118 M42 64 H118" stroke="%s" stroke-width="3" opacity="0.7"/>' % accent
			]))
		"void_tiles":
			return _void_tile_shape(asset_id, primary, secondary, accent)
		"object_scenes":
			return _object_scene_shape(asset_id, primary, secondary, accent)
		"biome_asset_sets":
			return "\n".join(PackedStringArray([
				'  <polygon points="80,14 146,50 80,86 14,50" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
				'  <circle cx="80" cy="50" r="20" fill="%s" stroke="#0b0b0b" stroke-width="4"/>' % secondary,
				'  <path d="M47 51 H113 M80 23 V78" stroke="%s" stroke-width="4" opacity="0.75"/>' % accent
			]))
		_:
			return '  <polygon points="80,18 142,54 80,90 18,54" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent]

func _void_tile_shape(
	asset_id: String,
	primary: String,
	secondary: String,
	accent: String
) -> String:
	var base := PackedStringArray([
		'  <polygon points="80,18 140,46 80,74 20,46" fill="%s" stroke="#101722" stroke-width="3"/>' % primary,
		'  <path d="M20 46 L80 74 L140 46 L140 82 L80 112 L20 82 Z" fill="#05070b" stroke="%s" stroke-width="2"/>' % secondary,
		'  <path d="M42 57 L44 88 M62 67 L63 99 M82 74 L82 108 M102 65 L100 98 M122 56 L118 87" stroke="%s" stroke-width="3" opacity="0.72"/>' % secondary,
		'  <path d="M24 84 C43 76 56 96 78 84 C98 73 116 91 136 81" fill="none" stroke="%s" stroke-width="4" opacity="0.28"/>' % accent
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
		return PackedStringArray(["M20 46 L80 18 L140 46"])
	if asset_id.ends_with("edge_south"):
		return PackedStringArray(["M20 46 L80 74 L140 46"])
	if asset_id.ends_with("edge_east"):
		return PackedStringArray(["M80 18 L140 46 L80 74"])
	if asset_id.ends_with("edge_west"):
		return PackedStringArray(["M80 18 L20 46 L80 74"])
	if asset_id.ends_with("inner_north_east"):
		return PackedStringArray(["M20 46 L80 18 L140 46 L80 74"])
	if asset_id.ends_with("inner_south_east"):
		return PackedStringArray(["M80 18 L140 46 L80 74 L20 46"])
	if asset_id.ends_with("inner_south_west"):
		return PackedStringArray(["M140 46 L80 74 L20 46 L80 18"])
	if asset_id.ends_with("inner_north_west"):
		return PackedStringArray(["M80 74 L20 46 L80 18 L140 46"])
	if asset_id.ends_with("outer_north_east"):
		return PackedStringArray(["M20 46 L80 18", "M80 18 L140 46"])
	if asset_id.ends_with("outer_south_east"):
		return PackedStringArray(["M80 18 L140 46", "M140 46 L80 74"])
	if asset_id.ends_with("outer_south_west"):
		return PackedStringArray(["M140 46 L80 74", "M80 74 L20 46"])
	if asset_id.ends_with("outer_north_west"):
		return PackedStringArray(["M80 74 L20 46", "M20 46 L80 18"])
	if asset_id.ends_with("north_east_south_west"):
		return PackedStringArray(["M20 46 L140 46"])
	if asset_id.ends_with("north_west_south_east"):
		return PackedStringArray(["M80 18 L80 74"])
	return PackedStringArray(["M20 46 L80 18 L140 46"])

func _terrain_tile_shape(asset_id: String, primary: String, secondary: String, accent: String) -> String:
	var base := PackedStringArray([
		'  <polygon points="80,18 142,54 80,90 18,54" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
		'  <path d="M32 54 L80 29 L128 54 L80 79 Z" fill="none" stroke="%s" stroke-width="3" opacity="0.42"/>' % secondary
	])
	if asset_id.contains("intersection"):
		base.append('  <path d="M37 40 L123 74 M123 40 L37 74" stroke="%s" stroke-width="10" stroke-linecap="round" opacity="0.72"/>' % accent)
	elif asset_id.contains("curve"):
		base.append('  <path d="M42 70 C62 42 90 34 122 48" fill="none" stroke="%s" stroke-width="11" stroke-linecap="round" opacity="0.72"/>' % accent)
	elif asset_id.contains("entry") or asset_id.contains("exit"):
		base.append('  <path d="M35 42 L83 68 L128 44" fill="none" stroke="%s" stroke-width="11" stroke-linecap="round" opacity="0.72"/>' % accent)
		base.append('  <path d="M80 32 L92 44 L80 56 L68 44 Z" fill="%s" opacity="0.85"/>' % secondary)
	elif _asset_is_route(asset_id):
		base.append('  <path d="M36 40 L124 76" stroke="%s" stroke-width="12" stroke-linecap="round" opacity="0.70"/>' % accent)
		base.append('  <path d="M42 72 L118 39" stroke="%s" stroke-width="5" stroke-linecap="round" opacity="0.38"/>' % secondary)
	else:
		base.append('  <path d="M40 57 L120 57" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.38"/>' % accent)
	return "\n".join(base)

func _object_scene_shape(asset_id: String, primary: String, secondary: String, accent: String) -> String:
	if asset_id.contains("house") or asset_id.contains("cabin") or asset_id.contains("lab_block") or asset_id.contains("lab_ruin"):
		return _building_shape(asset_id, primary, secondary, accent)
	if asset_id.contains("barrel"):
		return _barrel_shape(asset_id, primary, accent)
	if asset_id.contains("car") or asset_id.contains("wreck"):
		return _wreck_shape(primary, secondary, accent)
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
	if asset_id.contains("rock") or asset_id.contains("ice_block"):
		return _rock_shape(asset_id, primary, accent)
	if asset_id.contains("fence") or asset_id.contains("wall") or asset_id.contains("barrier"):
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

func _building_shape(asset_id: String, primary: String, secondary: String, accent: String) -> String:
	var lines := PackedStringArray([
		'  <polygon points="38,74 80,50 122,74 80,98" fill="%s" stroke="%s" stroke-width="3"/>' % [secondary, accent],
		'  <polygon points="40,42 80,20 120,42 80,64" fill="%s" stroke="#0b0c0d" stroke-width="4"/>' % accent,
		'  <polygon points="40,42 80,64 80,94 40,72" fill="%s" stroke="#0b0c0d" stroke-width="3"/>' % primary,
		'  <polygon points="120,42 80,64 80,94 120,72" fill="%s" stroke="#0b0c0d" stroke-width="3" opacity="0.82"/>' % primary,
		'  <path d="M60 73 L60 54 L72 60 L72 81 Z" fill="#090b0c" opacity="0.88"/>',
		'  <path d="M92 63 L107 55 L107 69 L92 78 Z" fill="#11181a" stroke="%s" stroke-width="2" opacity="0.92"/>' % accent
	])
	if asset_id.contains("ruin") or asset_id.contains("ruined"):
		lines.append('  <path d="M39 42 L56 31 L72 37 L85 22 L101 31 L119 42" fill="none" stroke="#111111" stroke-width="6" stroke-linecap="round"/>')
		lines.append('  <path d="M46 70 L62 78 M99 56 L116 50" stroke="#050505" stroke-width="4" stroke-linecap="round"/>')
	elif asset_id.contains("burn"):
		lines.append('  <path d="M47 43 L57 30 L65 43 L74 25 L86 47 L99 28 L114 43" fill="none" stroke="#090706" stroke-width="6" stroke-linecap="round"/>')
		lines.append('  <path d="M54 72 L111 49" stroke="#1b0e0a" stroke-width="5" stroke-linecap="round"/>')
	elif asset_id.contains("snow") or asset_id.contains("cabin"):
		lines.append('  <path d="M39 41 L80 18 L121 41" fill="none" stroke="#edf8fb" stroke-width="7" stroke-linecap="round"/>')
		lines.append('  <path d="M45 48 L80 66 L115 47" fill="none" stroke="#edf8fb" stroke-width="3" opacity="0.82"/>')
	elif asset_id.contains("sunken"):
		lines.append('  <path d="M34 84 C52 78 68 90 86 84 C105 78 121 88 138 81" fill="none" stroke="#7fc0a6" stroke-width="5" opacity="0.75"/>')
		lines.append('  <path d="M44 44 L78 25 L121 43" stroke="#0c1010" stroke-width="5" opacity="0.65"/>')
	elif asset_id.contains("lab"):
		lines.append('  <path d="M51 48 L80 33 L110 49 M50 60 L80 76 L110 60" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent)
		lines.append('  <circle cx="102" cy="61" r="5" fill="%s" opacity="0.82"/>' % accent)
	else:
		lines.append('  <path d="M48 48 L80 31 L112 48" stroke="#141414" stroke-width="4" opacity="0.75"/>')
	return "\n".join(lines)

func _barrier_shape(asset_id: String, primary: String, secondary: String, accent: String) -> String:
	var lines := PackedStringArray([
		'  <polygon points="30,78 80,54 130,78 80,102" fill="%s" stroke="%s" stroke-width="3"/>' % [secondary, accent]
	])
	if asset_id.contains("fence"):
		for x in [42, 58, 76, 96, 114]:
			lines.append('  <path d="M%d 76 L%d 42" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % [x, x + 6, primary])
		lines.append('  <path d="M34 66 L124 86 M38 52 L128 72" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % accent)
	elif asset_id.contains("pipe"):
		for y in [52, 66, 80]:
			lines.append('  <path d="M36 %d L116 %d" stroke="%s" stroke-width="12" stroke-linecap="round"/>' % [y, y + 13, primary])
			lines.append('  <ellipse cx="118" cy="%d" rx="8" ry="5" fill="%s" stroke="%s" stroke-width="2"/>' % [y + 13, secondary, accent])
	elif asset_id.contains("wall") or asset_id.contains("boundary"):
		lines.append('  <polygon points="34,48 126,70 126,88 34,66" fill="%s" stroke="#0b0b0b" stroke-width="4"/>' % primary)
		lines.append('  <path d="M48 54 L48 72 M68 59 L68 77 M88 64 L88 82 M108 69 L108 87" stroke="%s" stroke-width="3" opacity="0.82"/>' % accent)
	else:
		lines.append('  <path d="M34 70 L122 48 L128 66 L40 90 Z" fill="%s" stroke="#0b0b0b" stroke-width="4"/>' % primary)
		lines.append('  <path d="M45 76 L116 58 M63 83 L101 51" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent)
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

func _wreck_shape(primary: String, secondary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <polygon points="36,76 78,52 124,68 86,94" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
		'  <polygon points="43,63 73,45 111,58 126,76 85,86 52,76" fill="%s" stroke="#090909" stroke-width="4"/>' % primary,
		'  <polygon points="71,48 94,42 111,59 82,62" fill="#101416" stroke="%s" stroke-width="3"/>' % accent,
		'  <circle cx="58" cy="78" r="7" fill="#050505"/>',
		'  <circle cx="105" cy="78" r="7" fill="#050505"/>',
		'  <path d="M44 68 L118 75 M60 57 L96 83" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.72"/>' % accent
	]))

func _rock_shape(asset_id: String, primary: String, accent: String) -> String:
	var highlight := "#d6edf3" if asset_id.contains("ice") else accent
	return "\n".join(PackedStringArray([
		'  <polygon points="42,78 62,45 91,35 124,62 112,90 72,99" fill="%s" stroke="%s" stroke-width="4"/>' % [primary, accent],
		'  <polygon points="62,45 91,35 84,66 42,78" fill="%s" opacity="0.45"/>' % highlight,
		'  <path d="M84 66 L112 90 M84 66 L124 62 M72 99 L84 66" stroke="#0b0b0b" stroke-width="2" opacity="0.45"/>'
	]))

func _dense_vegetation_shape(primary: String, secondary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <polygon points="24,82 80,52 136,82 80,110" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
		'  <path d="M42 85 L47 47 M64 88 L66 35 M87 91 L86 29 M110 87 L111 42 M126 84 L128 58" stroke="#252016" stroke-width="8" stroke-linecap="round"/>',
		'  <circle cx="34" cy="59" r="23" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="57" cy="43" r="27" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="84" cy="37" r="30" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="109" cy="48" r="27" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="130" cy="64" r="22" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="70" cy="68" r="28" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <circle cx="103" cy="70" r="27" fill="%s" stroke="#101510" stroke-width="4"/>' % primary,
		'  <path d="M22 84 C36 67 50 74 62 65 C75 55 87 72 99 63 C113 53 128 70 139 83 L132 94 L80 111 L28 94 Z" fill="%s" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % [primary, accent]
	]))

func _debris_shape(primary: String, secondary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <polygon points="34,78 77,53 127,73 84,101" fill="%s" stroke="%s" stroke-width="4"/>' % [secondary, accent],
		'  <path d="M43 73 L76 48 L91 67 L119 56 L128 79 L96 91 L72 83 L50 94 Z" fill="%s" stroke="#0b0d0e" stroke-width="4"/>' % primary,
		'  <path d="M56 67 L106 85 M80 54 L72 88 M101 62 L114 77" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent
	]))

func _dead_tree_shape(primary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <path d="M79 91 C76 73 78 55 86 35" stroke="%s" stroke-width="10" stroke-linecap="round"/>' % primary,
		'  <path d="M84 52 L50 40 M84 56 L116 42 M81 69 L54 82 M82 46 L72 24 M88 39 L104 22" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % primary,
		'  <path d="M54 40 L43 33 M116 42 L128 35 M72 24 L68 15 M104 22 L116 17" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % accent,
		'  <ellipse cx="80" cy="94" rx="18" ry="7" fill="%s" opacity="0.7"/>' % primary
	]))

func _log_shape(primary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <path d="M38 70 L112 50 C122 47 132 55 128 64 L55 87 C44 91 32 80 38 70 Z" fill="%s" stroke="#090909" stroke-width="4"/>' % primary,
		'  <ellipse cx="45" cy="78" rx="12" ry="9" fill="%s" stroke="%s" stroke-width="3"/>' % [primary, accent],
		'  <path d="M58 76 L118 58 M76 69 L83 83 M97 61 L104 74" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % accent
	]))

func _bridge_object_shape(primary: String, secondary: String, accent: String) -> String:
	var lines := PackedStringArray([
		'  <polygon points="26,72 80,44 134,72 80,100" fill="%s" stroke="%s" stroke-width="3"/>' % [secondary, accent]
	])
	for index in range(6):
		var x_a := 39 + index * 15
		lines.append('  <path d="M%d 64 L%d 84" stroke="%s" stroke-width="8" stroke-linecap="round"/>' % [x_a, x_a + 15, primary])
	lines.append('  <path d="M31 65 L80 91 L129 65 M31 79 L80 105 L129 79" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % accent)
	return "\n".join(lines)

func _crate_shape(primary: String, secondary: String, accent: String) -> String:
	return "\n".join(PackedStringArray([
		'  <polygon points="50,68 80,52 110,68 80,84" fill="%s" stroke="%s" stroke-width="3"/>' % [secondary, accent],
		'  <polygon points="50,68 80,84 80,102 50,86" fill="%s" stroke="#0b0b0b" stroke-width="3"/>' % primary,
		'  <polygon points="110,68 80,84 80,102 110,86" fill="%s" stroke="#0b0b0b" stroke-width="3" opacity="0.82"/>' % primary,
		'  <path d="M58 72 L80 84 L102 72 M80 55 L80 101" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % accent
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
