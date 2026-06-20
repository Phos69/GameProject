extends RefCounted

const DEFAULT_PALETTE: Array[Color] = [
	Color(0.15, 0.18, 0.22, 1.0),
	Color(1.0, 0.72, 0.24, 1.0),
	Color(1.0, 0.48, 0.12, 0.45),
]

# Ordered as body, accent, glow. Keeping this table separate prevents catalog
# construction from accumulating presentation-only lookup functions.
const PALETTES: Dictionary = {
	# Firearms: metal/polymer body, grip/accent and mechanical glow.
	&"heavy_revolver": [Color(0.18, 0.18, 0.20, 1.0), Color(0.78, 0.62, 0.24, 1.0), Color(1.0, 0.72, 0.20, 0.30)],
	&"unstable_smg": [Color(0.22, 0.26, 0.18, 1.0), Color(0.52, 0.54, 0.50, 1.0), Color(0.60, 0.80, 0.20, 0.25)],
	&"pump_shotgun": [Color(0.28, 0.18, 0.10, 1.0), Color(0.24, 0.28, 0.34, 1.0), Color(1.0, 0.55, 0.15, 0.30)],
	&"tactical_carbine": [Color(0.12, 0.14, 0.16, 1.0), Color(0.74, 0.64, 0.44, 1.0), Color(0.90, 0.88, 0.72, 0.25)],
	&"improvised_sniper": [Color(0.30, 0.30, 0.32, 1.0), Color(0.42, 0.28, 0.16, 1.0), Color(0.92, 0.96, 1.0, 0.28)],
	&"grenade_launcher": [Color(0.30, 0.28, 0.14, 1.0), Color(0.38, 0.40, 0.38, 1.0), Color(0.70, 0.82, 0.22, 0.28)],
	&"sawed_off_double": [Color(0.20, 0.18, 0.16, 1.0), Color(0.46, 0.34, 0.22, 1.0), Color(1.0, 0.52, 0.16, 0.32)],
	&"burst_pistol": [Color(0.16, 0.18, 0.22, 1.0), Color(0.76, 0.80, 0.86, 1.0), Color(0.72, 0.86, 1.0, 0.26)],
	&"rusty_minigun": [Color(0.38, 0.22, 0.10, 1.0), Color(0.28, 0.26, 0.24, 1.0), Color(1.0, 0.66, 0.14, 0.35)],
	&"scrap_railgun": [Color(0.14, 0.18, 0.28, 1.0), Color(0.78, 0.52, 0.22, 1.0), Color(0.42, 0.96, 1.0, 0.42)],
	# Melee: blade/material body, handle/accent and impact aura.
	&"quick_knife": [Color(0.72, 0.76, 0.80, 1.0), Color(0.86, 0.80, 0.66, 1.0), Color(0.90, 0.96, 1.0, 0.30)],
	&"machete": [Color(0.34, 0.36, 0.34, 1.0), Color(0.28, 0.42, 0.24, 1.0), Color(0.50, 0.86, 0.38, 0.25)],
	&"heavy_axe": [Color(0.22, 0.22, 0.24, 1.0), Color(0.34, 0.22, 0.12, 1.0), Color(1.0, 0.48, 0.22, 0.35)],
	&"greatsword": [Color(0.64, 0.68, 0.72, 1.0), Color(0.82, 0.68, 0.24, 1.0), Color(0.90, 0.94, 1.0, 0.30)],
	&"demolition_hammer": [Color(0.50, 0.50, 0.50, 1.0), Color(1.0, 0.52, 0.10, 1.0), Color(1.0, 0.78, 0.24, 0.38)],
	&"spear": [Color(0.72, 0.66, 0.54, 1.0), Color(0.72, 0.56, 0.26, 1.0), Color(0.86, 0.72, 0.44, 0.28)],
	&"ruined_katana": [Color(0.44, 0.44, 0.46, 1.0), Color(0.60, 0.52, 0.44, 1.0), Color(0.80, 0.64, 1.0, 0.28)],
	&"spiked_mace": [Color(0.32, 0.20, 0.14, 1.0), Color(0.30, 0.22, 0.16, 1.0), Color(1.0, 0.26, 0.22, 0.32)],
	&"scythe": [Color(0.20, 0.22, 0.24, 1.0), Color(0.28, 0.20, 0.12, 1.0), Color(0.50, 1.0, 0.72, 0.32)],
	&"offensive_shield": [Color(0.28, 0.34, 0.44, 1.0), Color(0.52, 0.42, 0.30, 1.0), Color(0.72, 0.86, 1.0, 0.30)],
	# Elemental: crystal/organic body, energy accent and effect glow.
	&"fire_wand": [Color(0.36, 0.12, 0.08, 1.0), Color(1.0, 0.52, 0.14, 1.0), Color(1.0, 0.42, 0.12, 0.50)],
	&"fireball": [Color(0.90, 0.32, 0.08, 1.0), Color(1.0, 0.84, 0.20, 1.0), Color(1.0, 0.56, 0.16, 0.55)],
	&"ice_lance": [Color(0.68, 0.88, 0.98, 1.0), Color(0.24, 0.72, 0.96, 1.0), Color(0.52, 0.94, 1.0, 0.48)],
	&"frost_nova": [Color(0.88, 0.94, 1.0, 1.0), Color(0.36, 0.62, 0.90, 1.0), Color(0.48, 0.82, 1.0, 0.50)],
	&"chain_lightning": [Color(0.92, 0.90, 0.26, 1.0), Color(0.44, 0.72, 1.0, 1.0), Color(1.0, 0.96, 0.30, 0.55)],
	&"arcane_taser": [Color(0.52, 0.28, 0.78, 1.0), Color(1.0, 0.92, 0.24, 1.0), Color(0.74, 0.34, 1.0, 0.52)],
	&"acid_flask": [Color(0.28, 0.38, 0.18, 1.0), Color(0.72, 0.92, 0.16, 1.0), Color(0.52, 1.0, 0.24, 0.50)],
	&"toxic_spores": [Color(0.30, 0.36, 0.18, 1.0), Color(0.78, 0.82, 0.22, 1.0), Color(0.46, 0.96, 0.28, 0.48)],
	&"seismic_crystal": [Color(0.42, 0.24, 0.60, 1.0), Color(0.52, 0.44, 0.32, 1.0), Color(0.80, 0.54, 1.0, 0.50)],
	&"unstable_void": [Color(0.18, 0.08, 0.32, 1.0), Color(0.60, 0.24, 0.92, 1.0), Color(0.64, 0.24, 1.0, 0.60)],
}

static func has_palette(weapon_id: StringName) -> bool:
	return PALETTES.has(weapon_id)

static func get_primary_color(weapon_id: StringName) -> Color:
	return _get_palette(weapon_id)[0]

static func get_secondary_color(weapon_id: StringName) -> Color:
	return _get_palette(weapon_id)[1]

static func get_glow_color(weapon_id: StringName) -> Color:
	return _get_palette(weapon_id)[2]

static func _get_palette(weapon_id: StringName) -> Array:
	assert(PALETTES.has(weapon_id), "Missing catalog visual palette: %s" % weapon_id)
	return PALETTES.get(weapon_id, DEFAULT_PALETTE) as Array
