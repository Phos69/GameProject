extends RefCounted
class_name BiomeHazardCatalog

static func get_config(hazard_id: StringName) -> Dictionary:
	match hazard_id:
		&"toxic_puddle":
			return _config(3, 0.8, 0.82)
		&"gas_cloud":
			return _config(2, 1.0, 0.68)
		&"toxic_cloud":
			return _config(3, 0.7, 0.72, 4.0)
		&"fire_zone":
			return _config(5, 0.65, 0.92)
		&"lava_crack":
			return _config(8, 0.5, 0.78)
		&"explosion_trap", &"explosion":
			return _config(14, 1.2, 1.0, 0.4)
		&"fire_patch":
			return _config(4, 0.55, 0.86, 4.0)
		&"slippery_ice":
			return _config(0, 1.0, 1.12)
		&"deep_snow_slow":
			return _config(0, 1.0, 0.64)
		&"deep_water":
			return _config(2, 1.0, 0.42)
		&"mud_slow":
			return _config(0, 1.0, 0.58)
		&"mud_pool":
			return _config(0, 1.0, 0.58, 4.0)
		&"emerge_zone":
			return _config(0, 1.0, 0.90)
		_:
			return _config(0, 1.0, 1.0)

static func get_color(
	hazard_id: StringName,
	biome: BiomeDefinition
) -> Color:
	var base_color := Color(0.76, 0.34, 0.18, 0.82)
	if biome != null and biome.palette != null:
		base_color = biome.palette.hazard_color
	match hazard_id:
		&"gas_cloud", &"toxic_cloud":
			return base_color.lightened(0.18)
		&"lava_crack", &"fire_zone", &"fire_patch", &"explosion":
			return Color(1.0, 0.28, 0.06, 0.86)
		&"slippery_ice", &"deep_snow_slow":
			return Color(0.55, 0.90, 1.0, 0.78)
		&"deep_water", &"mud_slow", &"mud_pool":
			return Color(0.18, 0.58, 0.64, 0.78)
		_:
			return base_color

static func pascal_case(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		result += part.capitalize()
	return result

static func _config(
	damage: int,
	tick_interval: float,
	movement_multiplier: float,
	lifetime: float = 0.0
) -> Dictionary:
	return {
		"damage": damage,
		"tick_interval": tick_interval,
		"movement_multiplier": movement_multiplier,
		"lifetime": lifetime
	}
