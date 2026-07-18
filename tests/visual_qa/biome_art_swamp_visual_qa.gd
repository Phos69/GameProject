extends "res://tests/visual_qa/biome_rendering_review_visual_qa.gd"

const MARSH_OUTPUT_DIR := "res://build/qa/biome_art_fix/swamp"
const MARSH_BIOME_ID := &"swamp"
const MARSH_FOCUSES: Array[StringName] = [
	FOCUS_CENTER,
	FOCUS_PASSAGE,
	FOCUS_CLIFF,
	FOCUS_OBSTACLE,
	FOCUS_REED_WALL,
	FOCUS_PLAYER_ROSTER,
	FOCUS_ROUTE_TRANSITION,
]

func _get_output_dir() -> String:
	return MARSH_OUTPUT_DIR

func _get_review_biomes() -> Array[StringName]:
	return [MARSH_BIOME_ID]

func _get_focuses() -> Array[StringName]:
	return MARSH_FOCUSES.duplicate()

func _get_result_label() -> String:
	return "BIOME_ART_DROWNED_MARSH_VISUAL_QA"
