extends SceneTree

# Milestone 4 - Asset isometrici ambiente e ostacoli coerenti.
# Copre: manifest live e validato, copertura di tutti gli obstacle_id dei biomi,
# nessun asset esterno obbligatorio per il bootstrap, collisione/footprint/sort
# coerenti su BiomeObstacle (con fallback procedurale) e Y-sort abilitato nella
# scena principale per non coprire player/zombie/pickup in modo errato.

const BIOME_IDS: Array[String] = [
	"infected_plains",
	"toxic_wastes",
	"burning_fields",
	"frozen_outskirts",
	"drowned_marsh"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "manifest loads without error")
	_expect(manifest.version >= 2, "manifest version is current")

	var report := manifest.validate()
	_expect(bool(report.get("is_valid", false)), "manifest passes validation")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	_run_biome_coverage(manifest)
	_run_no_external_assets(manifest)
	_run_obstacle_coherence(manifest)
	_run_scene_y_sort()

	_finish()

func _run_biome_coverage(manifest: IsometricEnvironmentManifest) -> void:
	var missing := PackedStringArray()
	for biome_id in BIOME_IDS:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % biome_id) as BiomeDefinition
		if biome == null:
			_expect(false, "biome %s loads" % biome_id)
			continue
		for obstacle_id in biome.obstacle_ids:
			if not manifest.has_object(obstacle_id):
				missing.append("%s:%s" % [biome_id, String(obstacle_id)])
	_expect(
		missing.is_empty(),
		"every biome obstacle id is described in the manifest (%s)" % ", ".join(missing)
	)

func _run_no_external_assets(manifest: IsometricEnvironmentManifest) -> void:
	var external := PackedStringArray()
	for object_id in manifest.get_object_ids():
		if manifest.requires_external_asset(object_id):
			external.append(String(object_id))
	_expect(
		external.is_empty(),
		"no manifest object requires a mandatory external asset (%s)" % ", ".join(external)
	)

func _run_obstacle_coherence(manifest: IsometricEnvironmentManifest) -> void:
	var rectangle := _build_obstacle(manifest, &"ruined_house", Vector2(126.0, 78.0), &"rectangle")
	_expect(rectangle != null, "rectangle obstacle builds")
	if rectangle != null:
		var shape := rectangle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(shape != null and shape.shape is RectangleShape2D, "building has a rectangle collision footprint")
		_expect(rectangle.z_index == 0, "obstacle z_index is 0 so it participates in Y-sort")
		_expect(is_equal_approx(rectangle.sort_offset, manifest.get_sort_offset(&"ruined_house")), "obstacle sort offset comes from the manifest")
		_expect(rectangle.contains_global_position(rectangle.global_position), "rectangle footprint contains its center")
		rectangle.queue_free()

	var circle := _build_obstacle(manifest, &"small_rock", Vector2(48.0, 48.0), &"circle")
	_expect(circle != null, "circle obstacle builds")
	if circle != null:
		var shape := circle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(shape != null and shape.shape is CircleShape2D, "rock has a circle collision footprint")
		_expect(circle.get_clearance_radius() > 0.0, "rock exposes a positive clearance radius")
		circle.queue_free()

	# Procedural fallback: an id without explicit draw rules still builds safely.
	var fallback := _build_obstacle(manifest, &"wood_barrier", Vector2(108.0, 22.0), &"rectangle")
	_expect(fallback != null and fallback.get_node_or_null("CollisionShape2D") != null, "fallback obstacle still has collision")
	if fallback != null:
		fallback.queue_free()

func _run_scene_y_sort() -> void:
	var packed := load("res://game/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		return
	var state := packed.get_state()
	var required := {
		"World": false,
		"Enemies": false,
		"Pickups": false,
		"EnvironmentProps": false
	}
	for node_index in range(state.get_node_count()):
		var node_name := String(state.get_node_name(node_index))
		if not required.has(node_name):
			continue
		for property_index in range(state.get_node_property_count(node_index)):
			if String(state.get_node_property_name(node_index, property_index)) == "y_sort_enabled":
				if bool(state.get_node_property_value(node_index, property_index)):
					required[node_name] = true
	for node_name in required.keys():
		_expect(bool(required[node_name]), "%s has Y-sort enabled in main scene" % node_name)

func _build_obstacle(
	manifest: IsometricEnvironmentManifest,
	obstacle_id: StringName,
	size: Vector2,
	shape_id: StringName
) -> BiomeObstacle:
	var obstacle := BiomeObstacle.new()
	root.add_child(obstacle)
	obstacle.configure(
		obstacle_id,
		size,
		shape_id,
		0.0,
		Color(0.4, 0.4, 0.4, 1.0),
		Color(0.8, 0.8, 0.4, 1.0),
		manifest.get_sort_offset(obstacle_id)
	)
	return obstacle

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ISOMETRIC_ENVIRONMENT_MANIFEST_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_ENVIRONMENT_MANIFEST_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
