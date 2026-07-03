extends "res://tests/visual_qa/helpers/biome_art_pass_qa_base.gd"

## QA dedicata ART-VIS-FIX per il bioma toxic_wastes (tema urban_ruins).
## Output: build/qa/biome_art_fix/toxic_wastes/

func _init() -> void:
	biome_id = &"toxic_wastes"
	output_dir = "res://build/qa/biome_art_fix/toxic_wastes"
	qa_label = "BIOME_ART_TOXIC_WASTES_VISUAL_QA"
