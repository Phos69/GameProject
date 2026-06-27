extends RefCounted
class_name BiomeCell

enum BorderType {
	CONNECTED,
	BLOCKED,
	FALL,
	LOCKED_PASSAGE
}

const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]

var id: StringName = &""
var biome_id: StringName = &""
var grid: Vector2i = Vector2i.ZERO
var world_origin: Vector2i = Vector2i.ZERO
var width: int = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.x
var height: int = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.y
var seed: int = 0
var neighbors: Dictionary = {}
var borders: Dictionary = {}
var passages: Array[BiomePassage] = []
var generated_layout: BiomeEnvironmentLayout
var validation_report: Dictionary = {}

func configure(
	cell_id: StringName,
	resolved_biome_id: StringName,
	grid_position: Vector2i,
	zone_size: Vector2i,
	cell_seed: int
) -> void:
	id = cell_id
	biome_id = resolved_biome_id
	grid = grid_position
	width = zone_size.x
	height = zone_size.y
	world_origin = Vector2i(grid.x * width, grid.y * height)
	seed = cell_seed
	for side in SIDES:
		neighbors[side] = null
		borders[side] = BorderType.FALL

func set_neighbor(side: StringName, cell: BiomeCell) -> void:
	neighbors[side] = cell
	borders[side] = BorderType.CONNECTED if cell != null else BorderType.FALL

func get_neighbor(side: StringName) -> BiomeCell:
	return neighbors.get(side, null) as BiomeCell

func has_neighbor(side: StringName) -> bool:
	return get_neighbor(side) != null

func set_border(side: StringName, border_type: int) -> void:
	borders[side] = border_type

func get_border(side: StringName) -> int:
	return int(borders.get(side, BorderType.FALL))

func add_passage(passage: BiomePassage) -> void:
	if passage != null:
		passages.append(passage)

func get_passages_for_side(side: StringName) -> Array[BiomePassage]:
	var result: Array[BiomePassage] = []
	for passage in passages:
		if passage.side == side:
			result.append(passage)
	return result

func get_zone_size() -> Vector2i:
	return Vector2i(width, height)

func get_signature() -> String:
	var border_signature := PackedStringArray()
	for side in SIDES:
		border_signature.append("%s=%d" % [String(side), get_border(side)])
	var passage_signature := PackedStringArray()
	for passage in passages:
		passage_signature.append(passage.get_signature())
	passage_signature.sort()
	return "%s:%s:%s:%d:%s:%s" % [
		String(id),
		String(biome_id),
		str(grid),
		seed,
		"|".join(border_signature),
		"|".join(passage_signature)
	]

# Copia indipendente della cella, SENZA i link ai vicini: i neighbors puntano ad
# altre celle e vanno ricollegati dal chiamante una volta clonate tutte (vedi
# WorldDataCache). Bordi, passaggi e layout generato sono invece copiati a fondo.
func clone() -> BiomeCell:
	var copy := BiomeCell.new()
	copy.id = id
	copy.biome_id = biome_id
	copy.grid = grid
	copy.world_origin = world_origin
	copy.width = width
	copy.height = height
	copy.seed = seed
	copy.borders = borders.duplicate()
	for side in SIDES:
		copy.neighbors[side] = null
	copy.passages = []
	for passage in passages:
		if passage != null:
			copy.passages.append(passage.clone())
	copy.generated_layout = (
		generated_layout.clone() if generated_layout != null else null
	)
	copy.validation_report = validation_report.duplicate(true)
	return copy

# Ricollega i neighbors di una cella clonata usando la mappa id -> cella clonata.
func relink_neighbors(source: BiomeCell, clones_by_id: Dictionary) -> void:
	for side in SIDES:
		var source_neighbor := source.get_neighbor(side)
		if source_neighbor != null and clones_by_id.has(source_neighbor.id):
			neighbors[side] = clones_by_id[source_neighbor.id] as BiomeCell
		else:
			neighbors[side] = null

func clear_runtime_links() -> void:
	neighbors.clear()
	borders.clear()
	passages.clear()
	generated_layout = null
	validation_report.clear()

# --- Serializzazione (WorldSnapshotCodec / cache su disco) ------------------
# Rappresentazione a Dictionary salvabile con FileAccess.store_var(). Speculare a
# clone(): NON serializza i neighbor (puntano ad altre celle), che vengono
# ricollegati per `id` dal codec una volta deserializzate tutte le celle. Bordi,
# passaggi e layout generato sono invece serializzati a fondo.
func to_dict() -> Dictionary:
	var border_data := {}
	var neighbor_ids := {}
	for side in SIDES:
		border_data[String(side)] = get_border(side)
		var neighbor := get_neighbor(side)
		neighbor_ids[String(side)] = String(neighbor.id) if neighbor != null else ""
	var passage_data: Array = []
	for passage in passages:
		if passage != null:
			passage_data.append(passage.to_dict())
	return {
		"id": id,
		"biome_id": biome_id,
		"grid": grid,
		"world_origin": world_origin,
		"width": width,
		"height": height,
		"seed": seed,
		"borders": border_data,
		"neighbor_ids": neighbor_ids,
		"passages": passage_data,
		"generated_layout": generated_layout.to_dict() if generated_layout != null else null,
		"validation_report": validation_report.duplicate(true)
	}

# Ricollega i neighbor da una mappa {side: neighbor_id} (prodotta da to_dict) usando
# l'indice id -> cella. NON tocca i bordi (gia deserializzati), a differenza di
# set_neighbor() che li forzerebbe a CONNECTED.
func relink_neighbors_from_ids(
	neighbor_ids: Dictionary,
	cells_by_id: Dictionary
) -> void:
	for side in SIDES:
		var neighbor_id := String(neighbor_ids.get(String(side), ""))
		if neighbor_id.is_empty():
			neighbors[side] = null
			continue
		neighbors[side] = cells_by_id.get(StringName(neighbor_id), null) as BiomeCell

static func from_dict(data: Dictionary) -> BiomeCell:
	var cell := BiomeCell.new()
	cell.id = StringName(data.get("id", &""))
	cell.biome_id = StringName(data.get("biome_id", &""))
	cell.grid = data.get("grid", Vector2i.ZERO)
	cell.world_origin = data.get("world_origin", Vector2i.ZERO)
	cell.width = int(data.get("width", BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.x))
	cell.height = int(data.get("height", BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.y))
	cell.seed = int(data.get("seed", 0))
	var border_data := data.get("borders", {}) as Dictionary
	for side in SIDES:
		cell.neighbors[side] = null
		cell.borders[side] = int(border_data.get(String(side), BorderType.FALL))
	var typed_passages: Array[BiomePassage] = []
	for passage_dict in data.get("passages", []) as Array:
		typed_passages.append(BiomePassage.from_dict(passage_dict as Dictionary))
	cell.passages = typed_passages
	var layout_data: Variant = data.get("generated_layout", null)
	if layout_data is Dictionary:
		cell.generated_layout = BiomeEnvironmentLayout.from_dict(layout_data as Dictionary)
	cell.validation_report = (data.get("validation_report", {}) as Dictionary).duplicate(true)
	return cell
