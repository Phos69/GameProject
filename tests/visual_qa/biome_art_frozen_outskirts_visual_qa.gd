extends "res://tests/visual_qa/biome_rendering_review_visual_qa.gd"

const FROZEN_OUTPUT_DIR := "res://build/qa/biome_art_fix/frozen_outskirts"
const FROZEN_BIOME_ID := &"frozen_outskirts"
const FROZEN_FOCUSES: Array[StringName] = [
	FOCUS_CENTER,
	FOCUS_PASSAGE,
	FOCUS_CLIFF,
	FOCUS_OBSTACLE,
	FOCUS_PLAYER_ROSTER,
	FOCUS_ROUTE_TRANSITION,
]

func _get_output_dir() -> String:
	return FROZEN_OUTPUT_DIR

func _get_review_biomes() -> Array[StringName]:
	return [FROZEN_BIOME_ID]

func _get_focuses() -> Array[StringName]:
	return FROZEN_FOCUSES.duplicate()

func _get_result_label() -> String:
	return "BIOME_ART_FROZEN_OUTSKIRTS_VISUAL_QA"
