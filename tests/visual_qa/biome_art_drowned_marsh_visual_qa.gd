extends "res://tests/visual_qa/helpers/biome_art_pass_qa_base.gd"

## QA dedicata ART-VIS-FIX per il bioma drowned_marsh (tema swamp).
## Output: build/qa/biome_art_fix/drowned_marsh/

func _init() -> void:
	biome_id = &"drowned_marsh"
	output_dir = "res://build/qa/biome_art_fix/drowned_marsh"
	qa_label = "BIOME_ART_DROWNED_MARSH_VISUAL_QA"
