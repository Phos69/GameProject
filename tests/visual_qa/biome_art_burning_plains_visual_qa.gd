extends "res://tests/visual_qa/biome_rendering_review_visual_qa.gd"

const BURNING_OUTPUT_DIR := "res://build/qa/biome_art_fix/burning_plains"
const BURNING_BIOME_ID := &"burning_plains"
const BURNING_FOCUSES: Array[StringName] = [
	FOCUS_CENTER,
	FOCUS_PASSAGE,
	FOCUS_CLIFF,
	FOCUS_OBSTACLE,
	FOCUS_CRATE,
	FOCUS_PLAYER_ROSTER,
	FOCUS_ROUTE_TRANSITION,
]

func _get_output_dir() -> String:
	return BURNING_OUTPUT_DIR

func _get_review_biomes() -> Array[StringName]:
	return [BURNING_BIOME_ID]

func _get_focuses() -> Array[StringName]:
	return BURNING_FOCUSES.duplicate()

func _get_result_label() -> String:
	return "BIOME_ART_BURNING_FIELDS_VISUAL_QA"
