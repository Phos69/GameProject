extends RefCounted
class_name TileBakeCache

## Cache su disco (user://) dell'output COSTOSO del bake dei tile di un
## BiomeTileLayer: le sei mappe per-cella risolte dal resolver
## (tile_id/section/role/asset_path/material_asset_id/material_asset_path)
## + il conteggio asset mancanti.
##
## Il resolver per-cella e' la parte dominante del bake (vedi il commento in
## BiomeEnvironmentLayout.get_floor_tag_at_cell: "the difference between a
## multi-second tile-layer bake and an instant one"). Caricando queste mappe il
## bake salta l'intero loop di resolve: la successiva ricostruzione della
## geometria legge le mappe in O(1) invece di ri-risolvere ogni cella.
##
## NB: per ora si persiste solo il tile-cache (guadagno garantito e robusto). La
## geometria bakeata (mesh/linee) resta ricostruita da queste mappe; persistere
## anche le ArrayMesh e' un secondo step (vedi piano), da fare misurando il
## residuo, perche' richiede catturare tutto lo stato di render letto da _draw().

# Bump quando cambia il formato serializzato o il significato delle mappe.
const FORMAT_VERSION: int = 22
const DIR: String = "user://world_cache/bake/"
const EXT: String = ".bin"

static var _enabled: bool = true

static func set_enabled(value: bool) -> void:
	_enabled = value

static func is_enabled() -> bool:
	return _enabled

## Chiave deterministica del bake: dipende solo da cosa cambia le mappe risolte.
static func make_key(
	biome_id: StringName,
	quality_preset: StringName,
	layout_signature: String,
	chunk_size: int
) -> String:
	return "%s|%s|%s|%d" % [
		String(biome_id),
		String(quality_preset),
		layout_signature,
		chunk_size
	]

# Ritorna il payload {tile_id, tile_section, tile_role, asset_path,
# material_asset_id, material_asset_path, missing_asset_count, cell_count}
# o {} se assente/incompatibile.
static func fetch(key: String, expected_cell_count: int) -> Dictionary:
	if not _enabled or key.is_empty():
		return {}
	var path := _path(key)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var blob: Variant = file.get_var()
	file.close()
	if not (blob is Dictionary):
		return {}
	var data := blob as Dictionary
	if int(data.get("format_version", -1)) != FORMAT_VERSION:
		return {}
	if String(data.get("key", "")) != key:
		return {}
	if int(data.get("cell_count", -1)) != expected_cell_count:
		return {}
	return data.get("payload", {}) as Dictionary

static func store(key: String, expected_cell_count: int, payload: Dictionary) -> void:
	if not _enabled or key.is_empty():
		return
	_ensure_dir()
	var blob := {
		"format_version": FORMAT_VERSION,
		"key": key,
		"cell_count": expected_cell_count,
		"payload": payload
	}
	var path := _path(key)
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(blob)
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp_path, path)

static func clear() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		if file_name.ends_with(EXT) or file_name.ends_with(".tmp"):
			DirAccess.remove_absolute(DIR + file_name)

static func _path(key: String) -> String:
	return DIR + key.sha256_text() + EXT

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
