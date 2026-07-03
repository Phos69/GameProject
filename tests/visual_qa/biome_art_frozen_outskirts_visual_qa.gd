extends "res://tests/visual_qa/helpers/biome_art_pass_qa_base.gd"

## QA dedicata ART-VIS-FIX per il bioma frozen_outskirts (tema frozen_tundra).
## Output: build/qa/biome_art_fix/frozen_outskirts/

func _init() -> void:
	biome_id = &"frozen_outskirts"
	output_dir = "res://build/qa/biome_art_fix/frozen_outskirts"
	qa_label = "BIOME_ART_FROZEN_OUTSKIRTS_VISUAL_QA"
