extends "res://tests/visual_qa/biome_rendering_review_visual_qa.gd"

const TOXIC_OUTPUT_DIR := "res://build/qa/biome_art_fix/toxic_wastes"
const TOXIC_BIOME_ID := &"toxic_wastes"
const TOXIC_FOCUSES: Array[StringName] = [
	FOCUS_CENTER,
	FOCUS_PASSAGE,
	FOCUS_CLIFF,
	FOCUS_OBSTACLE,
	FOCUS_CRATE,
	FOCUS_PLAYER_ROSTER,
	FOCUS_ROUTE_TRANSITION,
]

func _get_output_dir() -> String:
	return TOXIC_OUTPUT_DIR

func _get_review_biomes() -> Array[StringName]:
	return [TOXIC_BIOME_ID]

func _get_focuses() -> Array[StringName]:
	return TOXIC_FOCUSES.duplicate()

func _get_result_label() -> String:
	return "BIOME_ART_TOXIC_WASTES_VISUAL_QA"
