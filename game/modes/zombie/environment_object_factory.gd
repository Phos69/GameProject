extends RefCounted
class_name EnvironmentObjectFactory

const BIOME_OBSTACLE_SCRIPT = preload(
	"res://game/modes/zombie/biome_obstacle.gd"
)
const ENVIRONMENT_OBJECT_SCENE = preload(
	"res://game/modes/zombie/environment_object.tscn"
)
const MISSING_ASSET_FALLBACK_STATUSES: Array[String] = [
	"needs_asset",
	"procedural_fallback",
	"deprecated"
]

var manifest: EnvironmentAssetManifest

func _init(next_manifest: EnvironmentAssetManifest = null) -> void:
	manifest = next_manifest
	if manifest == null:
		manifest = EnvironmentAssetManifest.get_shared()

func create_obstacle(
	obstacle_id: StringName,
	size: Vector2,
	shape_id: StringName,
	rotation_radians: float,
	base_color: Color,
	detail_color: Color,
	sort_offset: float = 0.0,
	asset_variant_id: StringName = &""
) -> BiomeObstacle:
	var obstacle := _instantiate_object(obstacle_id, asset_variant_id)
	if obstacle == null:
		return null
	if obstacle is EnvironmentObject:
		(obstacle as EnvironmentObject).asset_variant_id = asset_variant_id
	obstacle.configure(
		obstacle_id,
		size,
		shape_id,
		rotation_radians,
		base_color,
		detail_color,
		sort_offset
	)
	return obstacle

func should_use_asset_scene(
	obstacle_id: StringName,
	asset_variant_id: StringName = &""
) -> bool:
	if manifest == null:
		return false
	var contract := manifest.get_object_asset_contract(obstacle_id)
	if contract.is_empty():
		return false
	var asset_path := manifest.get_object_asset_path(obstacle_id, asset_variant_id)
	if not asset_path.is_empty() and _asset_path_exists(asset_path):
		return true
	return not _contract_requires_fallback(contract)

func _instantiate_object(
	obstacle_id: StringName,
	asset_variant_id: StringName = &""
) -> BiomeObstacle:
	if should_use_asset_scene(obstacle_id, asset_variant_id):
		var scene_object := (
			ENVIRONMENT_OBJECT_SCENE.instantiate()
			as BiomeObstacle
		)
		if scene_object != null:
			return scene_object
	var fallback := BIOME_OBSTACLE_SCRIPT.new() as BiomeObstacle
	return fallback

func _contract_requires_fallback(contract: Dictionary) -> bool:
	var status := String(contract.get("status", ""))
	if MISSING_ASSET_FALLBACK_STATUSES.has(status):
		return true
	var fallback_path := String(contract.get("fallback_path", ""))
	return fallback_path == "res://game/modes/zombie/biome_obstacle.gd"

func _asset_path_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)
