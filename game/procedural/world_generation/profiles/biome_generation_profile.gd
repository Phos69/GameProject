extends Resource
class_name BiomeGenerationProfile

## Typed tuning contract for the feature passes shared by every void-first biome.
## Asset paths, anchors and collision remain owned by the isometric manifest.

@export var biome_id: StringName = &"infected_plains"
@export var mesa_profile_id: StringName = &"forest"
@export_range(1, 24, 1) var mesa_min_count: int = 2
@export_range(1, 24, 1) var mesa_max_count: int = 4

@export_range(0, 64, 1) var random_prop_min_count: int = 10
@export_range(0, 64, 1) var random_prop_max_count: int = 16
@export var random_prop_ids: Array[StringName] = []
@export var random_prop_weights: Array[float] = []

@export_range(0, 8, 1) var internal_chasm_min_count: int = 1
@export_range(0, 8, 1) var static_hazard_max_count: int = 2
@export var static_hazard_ids: Array[StringName] = []
@export var static_hazard_sizes: Array[Vector2i] = []

func get_prop_rules() -> Array[Dictionary]:
	var rules: Array[Dictionary] = []
	for index in range(random_prop_ids.size()):
		var weight := (
			random_prop_weights[index]
			if index < random_prop_weights.size()
			else 1.0
		)
		rules.append({
			"id": random_prop_ids[index],
			"weight": maxf(weight, 0.0),
		})
	return rules

func get_static_hazard_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for hazard_id in static_hazard_ids:
		if hazard_id.is_empty() or result.has(hazard_id):
			continue
		result.append(hazard_id)
		if result.size() >= static_hazard_max_count:
			break
	return result

func get_static_hazard_size(hazard_id: StringName) -> Vector2i:
	var index := static_hazard_ids.find(hazard_id)
	if index < 0 or index >= static_hazard_sizes.size():
		return Vector2i.ZERO
	return static_hazard_sizes[index]

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if biome_id.is_empty():
		errors.append("biome_id is empty")
	if mesa_profile_id.is_empty():
		errors.append("mesa_profile_id is empty")
	if mesa_min_count > mesa_max_count:
		errors.append("mesa_min_count exceeds mesa_max_count")
	if random_prop_min_count > random_prop_max_count:
		errors.append("random_prop_min_count exceeds random_prop_max_count")
	if random_prop_ids.size() != random_prop_weights.size():
		errors.append("random prop ids/weights are not parallel")
	if static_hazard_ids.size() != static_hazard_sizes.size():
		errors.append("static hazard ids/sizes are not parallel")
	for index in range(random_prop_ids.size()):
		if random_prop_ids[index].is_empty():
			errors.append("random prop id %d is empty" % index)
		if index < random_prop_weights.size() and random_prop_weights[index] <= 0.0:
			errors.append("random prop weight %d is not positive" % index)
	for index in range(static_hazard_sizes.size()):
		var size := static_hazard_sizes[index]
		if size.x <= 0 or size.y <= 0:
			errors.append("static hazard size %d is invalid" % index)
	return errors
