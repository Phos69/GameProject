extends RefCounted

## Shared readiness contract for rendered Visual QA scenarios.
##
## A gameplay capture is valid only after the loading overlay is gone, the
## active tile layer has completed its build, the scenario-specific marker is
## present and (for streamed worlds) every visible chunk is committed.

const DEFAULT_TIMEOUT_MSEC := 150000
const STABLE_READY_FRAMES := 3
const DRAW_SETTLE_FRAMES := 2
const ISOMETRIC_SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)

static func wait_for_capture_ready(
	tree: SceneTree,
	scenario_marker: Callable,
	require_streaming: bool = true,
	require_terrain: bool = true,
	timeout_msec: int = DEFAULT_TIMEOUT_MSEC
) -> Dictionary:
	var deadline := Time.get_ticks_msec() + maxi(timeout_msec, 1)
	var next_diagnostic_msec := Time.get_ticks_msec() + 5000
	var stable_frames := 0
	var capture_world_rect := _capture_world_rect(tree)
	var result := _capture_readiness(
		tree,
		scenario_marker,
		require_streaming,
		require_terrain,
		capture_world_rect
	)
	while Time.get_ticks_msec() < deadline:
		capture_world_rect = _capture_world_rect(tree)
		if require_streaming:
			var streamer := tree.get_first_node_in_group(
				"world_region_streamer"
			) as WorldRegionStreamer
			if (
				streamer != null
				and int(
					streamer.get_streaming_stats().get(
						"gameplay_regions",
						0
					)
				) > 0
			):
				streamer.prepare_area(capture_world_rect)
		result = _capture_readiness(
			tree,
			scenario_marker,
			require_streaming,
			require_terrain,
			capture_world_rect
		)
		if bool(result.get("ready", false)):
			stable_frames += 1
			if stable_frames >= STABLE_READY_FRAMES:
				for _draw_frame in range(DRAW_SETTLE_FRAMES):
					await RenderingServer.frame_post_draw
				capture_world_rect = _capture_world_rect(tree)
				result = _capture_readiness(
					tree,
					scenario_marker,
					require_streaming,
					require_terrain,
					capture_world_rect
				)
				if bool(result.get("ready", false)):
					return result
				stable_frames = 0
		else:
			stable_frames = 0
		if Time.get_ticks_msec() >= next_diagnostic_msec:
			print(
				"VISUAL_QA_READINESS_WAIT: ",
				describe_failure(result),
				" stats=",
				result.get("streaming_stats", {})
			)
			next_diagnostic_msec = Time.get_ticks_msec() + 5000
		await tree.process_frame
	result["ready"] = false
	result["timed_out"] = true
	return result

static func describe_failure(result: Dictionary) -> String:
	if bool(result.get("ready", false)):
		return "ready"
	var blockers := PackedStringArray()
	if bool(result.get("loading_overlay", false)):
		blockers.append("loading overlay visible")
	if not bool(result.get("scenario_marker", false)):
		blockers.append("scenario marker missing")
	if (
		bool(result.get("terrain_required", false))
		and not bool(result.get("terrain_ready", false))
	):
		blockers.append("terrain build pending")
	if bool(result.get("streaming_required", false)):
		if not bool(result.get("streamer_active", false)):
			blockers.append("streamer inactive")
		if not bool(result.get("streaming_area_ready", false)):
			blockers.append("streamed area pending")
		if int(result.get("pending_regions", 0)) > 0:
			blockers.append(
				"pending_regions=%d"
				% int(result.get("pending_regions", 0))
			)
		if int(result.get("pending_content", 0)) > 0:
			blockers.append(
				"pending_content=%d"
				% int(result.get("pending_content", 0))
			)
		if int(result.get("visible_missing_chunks", -1)) != 0:
			blockers.append(
				"visible_missing_chunks=%d"
				% int(result.get("visible_missing_chunks", -1))
			)
	if blockers.is_empty():
		blockers.append("readiness timeout")
	return ", ".join(blockers)

static func has_loading_overlay(tree: SceneTree) -> bool:
	return (
		tree != null
		and tree.root != null
		and tree.root.find_child("WorldLoadingScreen", true, false) != null
	)

static func cleanup_scene(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	tree.current_scene = null
	for child in tree.root.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()
	await tree.process_frame
	await tree.process_frame
	WorldDataCache.clear()
	ISOMETRIC_SVG_TEXTURE_LOADER.clear_cache()
	IsometricEnvironmentManifest.clear_shared()
	await tree.process_frame

static func _capture_readiness(
	tree: SceneTree,
	scenario_marker: Callable,
	require_streaming: bool,
	require_terrain: bool,
	capture_world_rect: Rect2
) -> Dictionary:
	var marker_ready := (
		scenario_marker.is_null()
		or (
			scenario_marker.is_valid()
			and bool(scenario_marker.call())
		)
	)
	var terrain_ready := not require_terrain or _is_terrain_ready(tree)
	var streamer := tree.get_first_node_in_group(
		"world_region_streamer"
	) as WorldRegionStreamer
	var stats: Dictionary = {}
	var streamer_active := false
	var streaming_ready := not require_streaming
	var streaming_area_ready := not require_streaming
	if streamer != null:
		stats = streamer.get_streaming_stats()
		streaming_area_ready = streamer.is_area_ready(capture_world_rect)
		streamer_active = (
			int(stats.get("gameplay_regions", 0)) > 0
			and int(stats.get("loaded_visual_chunks", 0)) > 0
			and int(stats.get("visible_visual_chunks", 0)) > 0
		)
		streaming_ready = (
			not require_streaming
			or (
				streamer_active
				and streaming_area_ready
				and int(stats.get("visible_missing_chunks", -1)) == 0
				and int(stats.get("pending_regions", 0)) == 0
				and int(stats.get("pending_content", 0)) == 0
			)
		)
	var loading_overlay := has_loading_overlay(tree)
	return {
		"ready": (
			not loading_overlay
			and marker_ready
			and terrain_ready
			and streaming_ready
		),
		"loading_overlay": loading_overlay,
		"scenario_marker": marker_ready,
		"terrain_ready": terrain_ready,
		"terrain_required": require_terrain,
		"streaming_required": require_streaming,
		"streamer_active": streamer_active,
		"streaming_ready": streaming_ready,
		"streaming_area_ready": streaming_area_ready,
		"pending_regions": int(stats.get("pending_regions", 0)),
		"pending_content": int(stats.get("pending_content", 0)),
		"visible_missing_chunks": int(
			stats.get("visible_missing_chunks", -1 if require_streaming else 0)
		),
		"streaming_stats": stats,
		"timed_out": false
	}

static func _capture_world_rect(tree: SceneTree) -> Rect2:
	if tree == null or tree.root == null:
		return Rect2()
	var camera := tree.root.get_camera_2d()
	if camera == null:
		return Rect2()
	var viewport_size := tree.root.get_visible_rect().size
	var camera_zoom := Vector2(
		maxf(camera.zoom.x, 0.01),
		maxf(camera.zoom.y, 0.01)
	)
	var world_size := Vector2(
		viewport_size.x / camera_zoom.x,
		viewport_size.y / camera_zoom.y
	)
	return Rect2(
		camera.global_position - world_size * 0.5,
		world_size
	)

static func _is_terrain_ready(tree: SceneTree) -> bool:
	var terrain_generator := tree.get_first_node_in_group(
		"terrain_generator"
	) as TerrainGenerator
	if terrain_generator == null:
		return true
	var layer := terrain_generator.get_active_tile_layer()
	return (
		layer != null
		and (
			not layer.has_method("is_building")
			or not bool(layer.call("is_building"))
		)
	)
