extends "res://tests/visual_qa/helpers/biome_art_pass_qa_base.gd"

## QA dedicata ART-VIS-FIX per il bioma burning_fields (tema volcanic).
## Output: build/qa/biome_art_fix/burning_fields/

func _init() -> void:
	biome_id = &"burning_fields"
	output_dir = "res://build/qa/biome_art_fix/burning_fields"
	qa_label = "BIOME_ART_BURNING_FIELDS_VISUAL_QA"
