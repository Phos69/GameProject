extends RefCounted
class_name BiomePassageGenerator

const SIDES_TO_OPEN: Array[StringName] = [&"east", &"south"]

func generate_passages(cells: Array[BiomeCell], seed_value: int) -> void:
	for cell in cells:
		cell.passages.clear()

	for cell in cells:
		for side in SIDES_TO_OPEN:
			var neighbor := cell.get_neighbor(side)
			if neighbor == null:
				continue
			var local_seed := _derive_seed(seed_value, cell, neighbor, side)
			var rng := RandomNumberGenerator.new()
			rng.seed = local_seed
			var width := rng.randi_range(8, 14)
			var safe_min := 24
			var safe_max := cell.height - 24
			var position := rng.randi_range(safe_min, safe_max)
			var passage_type := _resolve_passage_type(
				cell.biome_id,
				neighbor.biome_id
			)
			_add_pair(
				cell,
				neighbor,
				side,
				position,
				width,
				passage_type,
				local_seed
			)

func _add_pair(
	cell: BiomeCell,
	neighbor: BiomeCell,
	side: StringName,
	position: int,
	width: int,
	passage_type: StringName,
	seed_value: int
) -> void:
	var forward := BiomePassage.new()
	forward.configure(
		cell,
		neighbor,
		side,
		position,
		width,
		passage_type,
		seed_value
	)
	cell.add_passage(forward)

	var backward := BiomePassage.new()
	backward.configure(
		neighbor,
		cell,
		BorderGenerator.get_opposite_side(side),
		position,
		width,
		passage_type,
		seed_value
	)
	neighbor.add_passage(backward)

func _resolve_passage_type(
	first_biome_id: StringName,
	second_biome_id: StringName
) -> StringName:
	var pair := "%s:%s" % [
		String(first_biome_id),
		String(second_biome_id)
	]
	if pair.contains("drowned") or pair.contains("marsh"):
		return &"bridge"
	if pair.contains("frozen"):
		return &"snow_pass"
	if pair.contains("toxic"):
		return &"broken_gate"
	if pair.contains("burning"):
		return &"burned_road"
	return &"road"

func _derive_seed(
	seed_value: int,
	cell: BiomeCell,
	neighbor: BiomeCell,
	side: StringName
) -> int:
	var raw := hash("%d:%s:%s:%s" % [
		seed_value,
		String(cell.id),
		String(neighbor.id),
		String(side)
	])
	return maxi(absi(raw), 1)
