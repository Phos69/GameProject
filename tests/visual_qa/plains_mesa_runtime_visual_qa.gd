extends "res://tests/visual_qa/biome_rendering_review_visual_qa.gd"

## Focused runtime regression for the exact Zombie Survival mesa path. It uses
## the production world, obstacle owner, Y-sort and terrain materials while
## keeping the review small enough to run after each cliff-atlas revision.

func _get_output_dir() -> String:
	return "res://build/qa/plains_mesa_runtime"

func _get_review_biomes() -> Array[StringName]:
	return [&"plains"]

func _get_review_seeds() -> Array[int]:
	return [641004, 772031]

func _get_review_resolutions() -> Array[Vector2i]:
	return [Vector2i(1280, 720), Vector2i(960, 540)]

func _get_focuses() -> Array[StringName]:
	return [&"mesa"]

func _focus_position(cell: BiomeCell, focus: StringName) -> Vector2:
	if (
		focus != &"mesa"
		or cell == null
		or cell.generated_layout == null
		or cell.generated_layout.mesa_rects.is_empty()
		or streamer == null
	):
		return super._focus_position(cell, focus)
	var layout := cell.generated_layout
	var mesa_rect: Rect2i = layout.mesa_rects.front()
	var east_side := layout.rect_geometric_center_to_world(mesa_rect) + Vector2(
		(float(mesa_rect.size.x) * 0.5 + 1.0) * layout.logical_tile_scale,
		0.0
	)
	return streamer.get_region_offset(cell.id) + east_side

func _get_result_label() -> String:
	return "PLAINS_MESA_RUNTIME_VISUAL_QA"
