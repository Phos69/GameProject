extends RefCounted
class_name WorldSnapshotCodec

## Converte un world_data (il Dictionary prodotto da BiomeWorldGenerator: seed,
## celle, grafo, start_cell, signature, seed_record) in una rappresentazione a
## Dictionary puro salvabile con FileAccess.store_var(), e viceversa.
##
## Serve a persistere il mondo golden su disco (user://) cosi il mondo buildato dai
## test e' lo stesso usato dal gameplay, senza rigenerarlo. Il WorldGraph NON viene
## serializzato: si ricostruisce in modo deterministico dalle celle con
## configure_from_biome_cells(), come gia fa WorldDataCache.clone_world_data().
##
## I neighbor delle celle sono ricollegati per `id` (vedi BiomeCell.to_dict /
## relink_neighbors_from_ids); start_cell e' identificata per `id`.

# Bump quando cambia il formato serializzato: snapshot con format_version diverso
# vengono ignorati e rigenerati (guardia di drift, lato cache su disco).
const FORMAT_VERSION: int = 4

static func world_data_to_dict(world_data: Dictionary) -> Dictionary:
	var cell_dicts: Array = []
	for cell in world_data.get("cells", []) as Array:
		var typed := cell as BiomeCell
		if typed != null:
			cell_dicts.append(typed.to_dict())
	var start_cell := world_data.get("start_cell", null) as BiomeCell
	return {
		"format_version": FORMAT_VERSION,
		"seed": int(world_data.get("seed", 0)),
		"signature": String(world_data.get("signature", "")),
		"start_cell_id": String(start_cell.id) if start_cell != null else "",
		"cells": cell_dicts,
		"seed_record": (world_data.get("seed_record", {}) as Dictionary).duplicate(true)
	}

# Restituisce {} se il blob e' incompatibile (format_version diverso o senza celle).
static func world_data_from_dict(data: Dictionary) -> Dictionary:
	if int(data.get("format_version", -1)) != FORMAT_VERSION:
		return {}
	var cell_dicts := data.get("cells", []) as Array
	if cell_dicts.is_empty():
		return {}
	var cells: Array[BiomeCell] = []
	var cells_by_id := {}
	for cell_dict in cell_dicts:
		var cell := BiomeCell.from_dict(cell_dict as Dictionary)
		cells.append(cell)
		cells_by_id[cell.id] = cell
	# Secondo passaggio: ricollega i neighbor ora che tutte le celle esistono.
	for index in range(cells.size()):
		var neighbor_ids := (cell_dicts[index] as Dictionary).get("neighbor_ids", {}) as Dictionary
		cells[index].relink_neighbors_from_ids(neighbor_ids, cells_by_id)
	var seed_value := int(data.get("seed", 0))
	var graph := WorldGraph.new()
	graph.configure_from_biome_cells(cells, seed_value)
	var start_cell: BiomeCell = null
	var start_cell_id := String(data.get("start_cell_id", ""))
	if not start_cell_id.is_empty():
		start_cell = cells_by_id.get(StringName(start_cell_id), null) as BiomeCell
	return {
		"seed": seed_value,
		"cells": cells,
		"world_graph": graph,
		"start_cell": start_cell,
		"signature": String(data.get("signature", "")),
		"seed_record": (data.get("seed_record", {}) as Dictionary).duplicate(true)
	}
