extends RefCounted
class_name WeaponCatalog

const PROJECTILE_SCENE: PackedScene = preload("res://game/projectiles/projectile.tscn")
const FIREARM_VISUAL: WeaponVisualData = preload("res://game/weapons/prototype_blaster_visual.tres")
const MELEE_VISUAL: WeaponVisualData = preload("res://game/weapons/rpg_sword_visual.tres")
const ELEMENTAL_VISUAL: WeaponVisualData = preload("res://game/weapons/wave_cannon_visual.tres")
const CATALOG_VISUAL_PALETTE := preload("res://game/weapons/weapon_catalog_visual_palette.gd")

static var _definitions: Dictionary = {}

static func get_all() -> Array[WeaponData]:
	_ensure_catalog()
	var result: Array[WeaponData] = []
	for definition in _definitions.values():
		result.append(definition as WeaponData)
	return result

static func get_definition(weapon_id: StringName) -> WeaponData:
	_ensure_catalog()
	return _definitions.get(weapon_id) as WeaponData

static func get_ids() -> Array[StringName]:
	_ensure_catalog()
	var ids: Array[StringName] = []
	for weapon_id in _definitions:
		ids.append(StringName(weapon_id))
	return ids

static func get_category(category_id: StringName) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for definition in get_all():
		if definition.category == category_id:
			result.append(definition)
	return result

static func _ensure_catalog() -> void:
	if not _definitions.is_empty():
		return
	var specs: Array[Dictionary] = [
		# Firearms: distinct spread, burst, pierce, charge, wind-up and AOE profiles.
		{"weapon_id": &"heavy_revolver", "display_name": "Revolver Pesante", "description": "Colpo lento ad alto impatto con forte rinculo sul bersaglio.", "damage": 42, "fire_rate": 1.6, "max_range": 620.0, "magazine_size": 6, "starting_reserve_ammo": 30, "reload_duration": 1.65, "knockback": 185.0, "rarity": &"uncommon"},
		{"weapon_id": &"unstable_smg", "display_name": "Mitraglietta Instabile", "description": "Raffica continua velocissima ma molto dispersa.", "damage": 7, "fire_rate": 13.0, "max_range": 430.0, "scatter_degrees": 15.0, "magazine_size": 32, "starting_reserve_ammo": 128, "reload_duration": 1.45},
		{"weapon_id": &"pump_shotgun", "display_name": "Fucile a Pompa", "description": "Cono di sette pallettoni devastante a distanza ravvicinata.", "damage": 9, "fire_rate": 1.05, "max_range": 250.0, "scatter_degrees": 22.0, "projectile_count": 7, "magazine_size": 6, "starting_reserve_ammo": 36, "reload_duration": 2.0, "knockback": 75.0},
		{"weapon_id": &"tactical_carbine", "display_name": "Carabina Tattica", "description": "Tiro preciso a medio raggio con munizione critica.", "damage": 19, "fire_rate": 5.4, "max_range": 760.0, "magazine_size": 18, "starting_reserve_ammo": 90, "reload_duration": 1.3, "effect_tags": [&"critical"], "effect_strength": 0.18},
		{"weapon_id": &"improvised_sniper", "display_name": "Sniper Improvvisato", "description": "Proiettile lento tra i colpi che penetra quattro nemici.", "damage": 68, "fire_rate": 0.72, "max_range": 1250.0, "projectile_speed": 1100.0, "max_hit_count": 4, "magazine_size": 4, "starting_reserve_ammo": 20, "reload_duration": 2.2, "effect_tags": [&"piercing"], "rarity": &"rare"},
		{"weapon_id": &"grenade_launcher", "display_name": "Lanciagranate", "description": "Granata lenta con traiettoria ad arco ed esplosione ritardata.", "damage": 48, "fire_rate": 0.8, "projectile_speed": 330.0, "max_range": 580.0, "projectile_arc_height": 68.0, "magazine_size": 4, "starting_reserve_ammo": 20, "reload_duration": 2.25, "aoe_radius": 105.0, "delayed_explosion": 0.25, "effect_tags": [&"explosion", &"aoe"], "rarity": &"rare"},
		{"weapon_id": &"sawed_off_double", "display_name": "Doppiette Segate", "description": "Due scariche corte da cinque pallettoni, range minimo.", "damage": 11, "fire_rate": 0.7, "max_range": 185.0, "scatter_degrees": 28.0, "projectile_count": 5, "burst_count": 2, "burst_interval": 0.12, "magazine_size": 2, "starting_reserve_ammo": 24, "reload_duration": 2.0, "knockback": 120.0},
		{"weapon_id": &"burst_pistol", "display_name": "Pistola Raffica", "description": "Premere una volta libera una raffica controllata da tre colpi.", "damage": 12, "fire_rate": 3.0, "max_range": 560.0, "burst_count": 3, "burst_interval": 0.075, "magazine_size": 15, "starting_reserve_ammo": 75, "reload_duration": 1.25},
		{"weapon_id": &"rusty_minigun", "display_name": "Minigun Arrugginita", "description": "Breve avviamento del rotore seguito da fuoco molto rapido.", "damage": 8, "fire_rate": 16.0, "max_range": 650.0, "scatter_degrees": 7.0, "windup_duration": 0.45, "magazine_size": 80, "starting_reserve_ammo": 240, "reload_duration": 3.2, "rarity": &"rare"},
		{"weapon_id": &"scrap_railgun", "display_name": "Railgun Artigianale", "description": "Carica lunga, raggio ad altissimo danno che attraversa sei bersagli.", "damage": 110, "fire_rate": 0.42, "projectile_speed": 1550.0, "max_range": 1500.0, "max_hit_count": 6, "charge_duration": 0.9, "magazine_size": 3, "starting_reserve_ammo": 12, "reload_duration": 2.6, "effect_tags": [&"charged_shot", &"piercing"], "rarity": &"epic"},

		# Melee: each profile changes geometry, timing, reach or status.
		{"weapon_id": &"quick_knife", "display_name": "Coltello Rapido", "description": "Affondi corti e rapidissimi.", "category": &"melee", "attack_type": &"melee_rect", "damage": 11, "fire_rate": 7.5, "melee_range": 54.0, "melee_width": 25.0, "max_hit_count": 1, "magazine_size": 12, "reload_duration": 0.35, "recovery_time": 0.04},
		{"weapon_id": &"machete", "display_name": "Machete", "description": "Arco frontale bilanciato per tre bersagli.", "category": &"melee", "attack_type": &"melee_arc", "damage": 25, "fire_rate": 2.6, "melee_range": 82.0, "melee_width": 68.0, "melee_arc_degrees": 105.0, "max_hit_count": 3, "magazine_size": 7, "reload_duration": 0.65},
		{"weapon_id": &"heavy_axe", "display_name": "Ascia Pesante", "description": "Cleave lento e brutale con forte knockback.", "category": &"melee", "attack_type": &"melee_arc", "damage": 54, "fire_rate": 0.9, "melee_range": 95.0, "melee_width": 88.0, "melee_arc_degrees": 125.0, "windup_time": 0.25, "recovery_time": 0.38, "knockback": 150.0, "max_hit_count": 5, "magazine_size": 4, "reload_duration": 0.9, "effect_tags": [&"cleave"]},
		{"weapon_id": &"greatsword", "display_name": "Spadone", "description": "Fendente enorme che pulisce tutto il fronte.", "category": &"melee", "attack_type": &"melee_sweep", "damage": 44, "fire_rate": 1.05, "melee_range": 128.0, "melee_width": 120.0, "melee_arc_degrees": 155.0, "max_hit_count": 8, "magazine_size": 4, "reload_duration": 0.85, "rarity": &"uncommon"},
		{"weapon_id": &"demolition_hammer", "display_name": "Martello da Demolizione", "description": "Colpo pesante che stordisce ciò che sopravvive.", "category": &"melee", "attack_type": &"melee_arc", "damage": 62, "fire_rate": 0.72, "melee_range": 86.0, "melee_width": 92.0, "windup_time": 0.38, "recovery_time": 0.5, "knockback": 210.0, "max_hit_count": 4, "magazine_size": 3, "reload_duration": 1.1, "effect_tags": [&"stun"], "effect_duration": 1.0, "effect_strength": 1.0, "rarity": &"rare"},
		{"weapon_id": &"spear", "display_name": "Lancia", "description": "Affondo lineare molto lungo e stretto.", "category": &"melee", "attack_type": &"melee_rect", "damage": 34, "fire_rate": 1.8, "melee_range": 155.0, "melee_width": 28.0, "max_hit_count": 4, "magazine_size": 6, "reload_duration": 0.65, "effect_tags": [&"piercing"]},
		{"weapon_id": &"ruined_katana", "display_name": "Katana Rovinata", "description": "Taglio rapido con breve profilo dash.", "category": &"melee", "attack_type": &"dash_slash", "damage": 38, "fire_rate": 1.65, "melee_range": 135.0, "melee_width": 48.0, "max_hit_count": 5, "magazine_size": 5, "reload_duration": 0.8, "effect_tags": [&"dash_slash"], "rarity": &"rare"},
		{"weapon_id": &"spiked_mace", "display_name": "Mazza Chiodata", "description": "Impatto che lascia sanguinamento persistente.", "category": &"melee", "attack_type": &"melee_arc", "damage": 31, "fire_rate": 1.45, "melee_range": 78.0, "melee_width": 76.0, "max_hit_count": 3, "magazine_size": 5, "reload_duration": 0.75, "effect_tags": [&"bleed"], "effect_duration": 4.0, "effect_strength": 0.45},
		{"weapon_id": &"scythe", "display_name": "Falce", "description": "Arco larghissimo, efficace contro gruppi compatti.", "category": &"melee", "attack_type": &"melee_arc", "damage": 29, "fire_rate": 1.25, "melee_range": 118.0, "melee_width": 150.0, "melee_arc_degrees": 210.0, "max_hit_count": 10, "magazine_size": 5, "reload_duration": 0.85, "effect_tags": [&"group_bonus"]},
		{"weapon_id": &"offensive_shield", "display_name": "Scudo Offensivo", "description": "Urto corto che respinge e concede controllo difensivo.", "category": &"melee", "attack_type": &"melee_rect", "damage": 20, "fire_rate": 2.0, "melee_range": 58.0, "melee_width": 74.0, "knockback": 240.0, "max_hit_count": 4, "magazine_size": 8, "reload_duration": 0.6, "effect_tags": [&"defensive_bash"]},

		# Elemental weapons cover DOT, AOE, freeze, chain, stun, hazards and pull.
		{"weapon_id": &"fire_wand", "display_name": "Bacchetta di Fuoco", "description": "Dardo incendiario che applica bruciatura.", "category": &"elemental", "damage": 18, "fire_rate": 3.4, "max_range": 620.0, "magazine_size": 10, "starting_reserve_ammo": 50, "reload_duration": 1.35, "effect_tags": [&"burn"], "effect_duration": 3.5, "effect_strength": 0.45},
		{"weapon_id": &"fireball", "display_name": "Palla di Fuoco", "description": "Sfera lenta che esplode e incendia un'area.", "category": &"elemental", "damage": 45, "fire_rate": 0.85, "projectile_speed": 390.0, "max_range": 620.0, "magazine_size": 5, "starting_reserve_ammo": 25, "reload_duration": 1.8, "aoe_radius": 96.0, "effect_tags": [&"explosion", &"aoe", &"burn"], "effect_duration": 2.5, "effect_strength": 0.35},
		{"weapon_id": &"ice_lance", "display_name": "Lancia Ghiacciata", "description": "Scheggia penetrante che rallenta e può congelare.", "category": &"elemental", "damage": 31, "fire_rate": 1.45, "max_range": 900.0, "max_hit_count": 3, "magazine_size": 6, "starting_reserve_ammo": 30, "reload_duration": 1.55, "effect_tags": [&"slow", &"freeze", &"piercing"], "effect_duration": 2.2, "effect_strength": 0.55},
		{"weapon_id": &"frost_nova", "display_name": "Nova Gelida", "description": "Esplosione corta attorno al punto d'impatto che congela.", "category": &"elemental", "damage": 24, "fire_rate": 0.55, "projectile_speed": 220.0, "max_range": 70.0, "magazine_size": 3, "starting_reserve_ammo": 18, "reload_duration": 2.1, "aoe_radius": 145.0, "effect_tags": [&"aoe", &"freeze"], "effect_duration": 1.25, "effect_strength": 0.85, "rarity": &"rare"},
		{"weapon_id": &"chain_lightning", "display_name": "Fulmine a Catena", "description": "Scarica che salta verso quattro bersagli vicini.", "category": &"elemental", "damage": 28, "fire_rate": 1.15, "projectile_speed": 980.0, "max_range": 720.0, "magazine_size": 7, "starting_reserve_ammo": 35, "reload_duration": 1.5, "chain_targets": 4, "chain_range": 190.0, "effect_tags": [&"chain_lightning", &"stun"], "effect_duration": 0.22, "effect_strength": 0.35, "rarity": &"rare"},
		{"weapon_id": &"arcane_taser", "display_name": "Taser Arcano", "description": "Colpo singolo corto che stordisce a lungo.", "category": &"elemental", "damage": 13, "fire_rate": 1.7, "max_range": 340.0, "magazine_size": 8, "starting_reserve_ammo": 40, "reload_duration": 1.15, "effect_tags": [&"stun"], "effect_duration": 1.4, "effect_strength": 1.0},
		{"weapon_id": &"acid_flask", "display_name": "Ampolla Acida", "description": "Crea una pozza corrosiva temporanea.", "category": &"elemental", "damage": 20, "fire_rate": 0.75, "projectile_speed": 350.0, "max_range": 520.0, "magazine_size": 4, "starting_reserve_ammo": 20, "reload_duration": 1.9, "aoe_radius": 84.0, "ground_hazard_duration": 5.0, "effect_tags": [&"poison", &"ground_hazard"], "effect_duration": 2.0, "effect_strength": 0.4},
		{"weapon_id": &"toxic_spores", "display_name": "Spore Tossiche", "description": "Nube ampia e persistente di veleno.", "category": &"elemental", "damage": 12, "fire_rate": 0.62, "projectile_speed": 280.0, "max_range": 460.0, "magazine_size": 4, "starting_reserve_ammo": 20, "reload_duration": 2.0, "aoe_radius": 125.0, "ground_hazard_duration": 6.5, "effect_tags": [&"poison", &"aoe", &"ground_hazard"], "effect_duration": 4.0, "effect_strength": 0.5},
		{"weapon_id": &"seismic_crystal", "display_name": "Cristallo Sismico", "description": "Onda d'urto radiale con danno e forte knockback.", "category": &"elemental", "damage": 38, "fire_rate": 0.68, "projectile_speed": 250.0, "max_range": 120.0, "magazine_size": 3, "starting_reserve_ammo": 15, "reload_duration": 2.2, "aoe_radius": 175.0, "knockback": 260.0, "effect_tags": [&"aoe", &"seismic_wave"], "rarity": &"rare"},
		{"weapon_id": &"unstable_void", "display_name": "Vuoto Instabile", "description": "Implosione ritardata che attira e poi esplode.", "category": &"elemental", "damage": 58, "fire_rate": 0.42, "projectile_speed": 310.0, "max_range": 650.0, "magazine_size": 2, "starting_reserve_ammo": 10, "reload_duration": 2.8, "aoe_radius": 135.0, "delayed_explosion": 0.85, "knockback": 120.0, "effect_tags": [&"pull", &"delayed_explosion", &"aoe"], "rarity": &"epic"}
	]
	for spec in specs:
		var definition := _make_definition(spec)
		_definitions[definition.weapon_id] = definition

static func _make_definition(spec: Dictionary) -> WeaponData:
	var definition := WeaponData.new()
	definition.weapon_id = StringName(spec.get("weapon_id", &"weapon"))
	definition.display_name = str(spec.get("display_name", "Weapon"))
	definition.description = str(spec.get("description", ""))
	definition.category = StringName(spec.get("category", &"firearm"))
	definition.rarity = StringName(spec.get("rarity", &"common"))
	definition.damage = int(spec.get("damage", 10))
	definition.fire_rate = float(spec.get("fire_rate", 2.0))
	definition.projectile_speed = float(spec.get("projectile_speed", 700.0))
	definition.max_range = float(spec.get("max_range", 600.0))
	definition.projectile_arc_height = float(spec.get("projectile_arc_height", 0.0))
	definition.scatter_degrees = float(spec.get("scatter_degrees", 0.0))
	definition.attack_type = StringName(spec.get("attack_type", &"projectile"))
	definition.hitbox_type = StringName(spec.get("hitbox_type", &"circle"))
	definition.hitbox_size = spec.get("hitbox_size", Vector2(10.0, 10.0)) as Vector2
	definition.max_hit_count = int(spec.get("max_hit_count", 1))
	definition.melee_range = float(spec.get("melee_range", 0.0))
	definition.melee_width = float(spec.get("melee_width", 0.0))
	definition.melee_arc_degrees = float(spec.get("melee_arc_degrees", 90.0))
	definition.windup_time = float(spec.get("windup_time", 0.0))
	definition.active_time = float(spec.get("active_time", 0.1))
	definition.recovery_time = float(spec.get("recovery_time", 0.0))
	definition.knockback = float(spec.get("knockback", 0.0))
	definition.trail_style = StringName(
		spec.get(
			"trail_style",
			_melee_impact_vfx_for(definition.weapon_id)
			if definition.category == &"melee"
			else &""
		)
	)
	definition.effect_key = StringName(spec.get("effect_key", &""))
	definition.magazine_size = int(spec.get("magazine_size", 8))
	definition.starting_reserve_ammo = int(spec.get("starting_reserve_ammo", 0))
	definition.reload_duration = float(spec.get("reload_duration", 1.0))
	definition.infinite_reserve_ammo = definition.category == &"melee"
	definition.projectile_count = int(spec.get("projectile_count", 1))
	definition.burst_count = int(spec.get("burst_count", 1))
	definition.burst_interval = float(spec.get("burst_interval", 0.08))
	definition.charge_duration = float(spec.get("charge_duration", 0.0))
	definition.windup_duration = float(spec.get("windup_duration", 0.0))
	definition.delayed_explosion = float(spec.get("delayed_explosion", 0.0))
	definition.aoe_radius = float(spec.get("aoe_radius", 0.0))
	definition.chain_targets = int(spec.get("chain_targets", 0))
	definition.chain_range = float(spec.get("chain_range", 0.0))
	definition.ground_hazard_duration = float(spec.get("ground_hazard_duration", 0.0))
	definition.effect_tags.clear()
	for tag in spec.get("effect_tags", []) as Array:
		definition.effect_tags.append(StringName(tag))
	definition.effect_duration = float(spec.get("effect_duration", 0.0))
	definition.effect_strength = float(spec.get("effect_strength", 0.0))
	definition.projectile_scene = PROJECTILE_SCENE if definition.category != &"melee" else null
	var base_visual := FIREARM_VISUAL
	match definition.category:
		&"melee":
			base_visual = MELEE_VISUAL
		&"elemental":
			base_visual = ELEMENTAL_VISUAL
	definition.visual_data = _make_visual_data(definition, base_visual)
	return definition

static func _make_visual_data(
	definition: WeaponData,
	base_visual: WeaponVisualData
) -> WeaponVisualData:
	var visual := WeaponVisualData.new()
	if base_visual != null:
		visual.profile_id = base_visual.profile_id
		visual.primary_color = base_visual.primary_color
		visual.secondary_color = base_visual.secondary_color
		visual.glow_color = base_visual.glow_color
		visual.muzzle_color = base_visual.muzzle_color
		visual.projectile_color = base_visual.projectile_color
		visual.projectile_glow_color = base_visual.projectile_glow_color
		visual.projectile_scale = base_visual.projectile_scale
		visual.held_shape_id = base_visual.held_shape_id
		visual.hud_shape_id = base_visual.hud_shape_id
		visual.projectile_shape_id = base_visual.projectile_shape_id
		visual.slash_shape_id = base_visual.slash_shape_id
		visual.impact_shape_id = base_visual.impact_shape_id
		visual.muzzle_shape_id = base_visual.muzzle_shape_id
		visual.impact_vfx_id = base_visual.impact_vfx_id
		visual.outline_color = base_visual.outline_color
		visual.pickup_scale = base_visual.pickup_scale
		visual.held_scale = base_visual.held_scale
		visual.pickup_sprite_path = base_visual.pickup_sprite_path
		visual.held_sprite_path = base_visual.held_sprite_path
		visual.projectile_sprite_path = base_visual.projectile_sprite_path
		visual.slash_sprite_path = base_visual.slash_sprite_path
		visual.weapon_length = base_visual.weapon_length
		visual.weapon_width = base_visual.weapon_width
		visual.muzzle_size = base_visual.muzzle_size
		visual.trail_length = base_visual.trail_length
		visual.trail_width = base_visual.trail_width
	visual.family_id = definition.category
	visual.pickup_shape_id = definition.weapon_id
	visual.held_shape_id = definition.weapon_id
	visual.hud_shape_id = definition.weapon_id
	if definition.category != &"melee":
		visual.projectile_shape_id = definition.weapon_id
		visual.impact_shape_id = definition.weapon_id
		visual.muzzle_shape_id = definition.weapon_id
		visual.impact_vfx_id = _impact_vfx_for(definition.weapon_id)
		visual.projectile_color = _projectile_color_for(definition.weapon_id)
		visual.projectile_glow_color = _projectile_glow_color_for(definition.weapon_id)
		visual.muzzle_color = _muzzle_color_for(definition.weapon_id)
		visual.projectile_scale = _projectile_scale_for(definition.weapon_id)
		visual.trail_length = _trail_length_for(definition.weapon_id)
		visual.trail_width = _trail_width_for(definition.weapon_id)
		visual.muzzle_size = _muzzle_size_for(definition.weapon_id)
	else:
		visual.slash_shape_id = definition.weapon_id
		visual.impact_shape_id = definition.weapon_id
		visual.impact_vfx_id = _melee_impact_vfx_for(definition.weapon_id)
		visual.projectile_color = _melee_slash_color_for(definition.weapon_id)
		visual.projectile_glow_color = _melee_slash_glow_for(definition.weapon_id)
		visual.trail_width = _melee_trail_width_for(definition.weapon_id)
	visual.profile_id = definition.weapon_id
	visual.primary_color = CATALOG_VISUAL_PALETTE.get_primary_color(definition.weapon_id)
	visual.secondary_color = CATALOG_VISUAL_PALETTE.get_secondary_color(definition.weapon_id)
	visual.glow_color = CATALOG_VISUAL_PALETTE.get_glow_color(definition.weapon_id)
	visual.rarity_glow = _rarity_glow_for(definition.rarity)
	visual.outline_color = _rarity_outline_for(definition.rarity)
	var visual_size := _visual_size_for(definition.weapon_id)
	visual.weapon_length = visual_size.x
	visual.weapon_width = visual_size.y
	visual.pickup_scale = _pickup_scale_for(definition.weapon_id)
	return visual

static func _visual_size_for(weapon_id: StringName) -> Vector2:
	match weapon_id:
		&"heavy_revolver":
			return Vector2(22.0, 7.0)
		&"unstable_smg":
			return Vector2(28.0, 7.0)
		&"pump_shotgun":
			return Vector2(36.0, 8.0)
		&"tactical_carbine":
			return Vector2(34.0, 6.0)
		&"improvised_sniper":
			return Vector2(44.0, 5.0)
		&"grenade_launcher":
			return Vector2(36.0, 12.0)
		&"sawed_off_double":
			return Vector2(28.0, 9.0)
		&"burst_pistol":
			return Vector2(23.0, 6.0)
		&"rusty_minigun":
			return Vector2(38.0, 13.0)
		&"scrap_railgun":
			return Vector2(46.0, 8.0)
		&"quick_knife":
			return Vector2(18.0, 4.0)
		&"machete":
			return Vector2(28.0, 7.0)
		&"heavy_axe":
			return Vector2(34.0, 12.0)
		&"greatsword":
			return Vector2(38.0, 7.0)
		&"demolition_hammer":
			return Vector2(34.0, 14.0)
		&"spear":
			return Vector2(44.0, 4.0)
		&"ruined_katana":
			return Vector2(35.0, 5.0)
		&"spiked_mace":
			return Vector2(30.0, 12.0)
		&"scythe":
			return Vector2(40.0, 13.0)
		&"offensive_shield":
			return Vector2(24.0, 14.0)
		&"fire_wand":
			return Vector2(26.0, 5.0)
		&"fireball":
			return Vector2(20.0, 14.0)
		&"ice_lance":
			return Vector2(36.0, 7.0)
		&"frost_nova":
			return Vector2(24.0, 14.0)
		&"chain_lightning":
			return Vector2(30.0, 10.0)
		&"arcane_taser":
			return Vector2(24.0, 7.0)
		&"acid_flask":
			return Vector2(22.0, 12.0)
		&"toxic_spores":
			return Vector2(23.0, 13.0)
		&"seismic_crystal":
			return Vector2(26.0, 14.0)
		&"unstable_void":
			return Vector2(25.0, 14.0)
		_:
			return Vector2(26.0, 7.0)

static func _pickup_scale_for(weapon_id: StringName) -> Vector2:
	var visual_size := _visual_size_for(weapon_id)
	return Vector2(
		clampf(visual_size.x / 24.0, 0.95, 1.35),
		clampf(visual_size.y / 7.5, 0.95, 1.35)
	)

static func _melee_impact_vfx_for(weapon_id: StringName) -> StringName:
	match weapon_id:
		&"quick_knife":
			return &"quick_stab"
		&"machete":
			return &"machete_cleave"
		&"heavy_axe":
			return &"heavy_cleave"
		&"greatsword":
			return &"broad_sweep"
		&"demolition_hammer":
			return &"hammer_shockwave"
		&"spear":
			return &"spear_thrust"
		&"ruined_katana":
			return &"katana_dash_cut"
		&"spiked_mace":
			return &"spiked_impact"
		&"scythe":
			return &"scythe_crescent"
		&"offensive_shield":
			return &"shield_bash"
		_:
			return &"melee_hit"

static func _melee_slash_color_for(weapon_id: StringName) -> Color:
	match weapon_id:
		&"quick_knife":
			return Color(0.92, 0.96, 1.0, 1.0)
		&"machete":
			return Color(0.70, 0.88, 0.64, 1.0)
		&"heavy_axe":
			return Color(1.0, 0.48, 0.26, 1.0)
		&"greatsword":
			return Color(0.76, 0.90, 1.0, 1.0)
		&"demolition_hammer":
			return Color(1.0, 0.72, 0.32, 1.0)
		&"spear":
			return Color(0.68, 0.94, 1.0, 1.0)
		&"ruined_katana":
			return Color(0.96, 0.86, 1.0, 1.0)
		&"spiked_mace":
			return Color(1.0, 0.42, 0.38, 1.0)
		&"scythe":
			return Color(0.56, 1.0, 0.78, 1.0)
		&"offensive_shield":
			return Color(0.78, 0.88, 1.0, 1.0)
		_:
			return Color(0.92, 0.96, 1.0, 1.0)

static func _melee_slash_glow_for(weapon_id: StringName) -> Color:
	var color := _melee_slash_color_for(weapon_id)
	match weapon_id:
		&"heavy_axe", &"demolition_hammer", &"spiked_mace":
			return Color(color.lightened(0.10), 0.82)
		&"scythe":
			return Color(0.46, 1.0, 0.66, 0.78)
		&"ruined_katana":
			return Color(0.90, 0.66, 1.0, 0.74)
		&"offensive_shield":
			return Color(0.62, 0.78, 1.0, 0.72)
		_:
			return Color(color.lightened(0.18), 0.68)

static func _melee_trail_width_for(weapon_id: StringName) -> float:
	match weapon_id:
		&"quick_knife", &"spear", &"ruined_katana":
			return 3.0
		&"machete", &"spiked_mace", &"offensive_shield":
			return 4.5
		&"heavy_axe", &"greatsword", &"demolition_hammer", &"scythe":
			return 6.0
		_:
			return 4.0

static func _impact_vfx_for(weapon_id: StringName) -> StringName:
	match weapon_id:
		&"grenade_launcher", &"fireball":
			return &"explosive"
		&"scrap_railgun":
			return &"rail"
		&"fire_wand":
			return &"fire"
		&"ice_lance", &"frost_nova":
			return &"ice"
		&"chain_lightning", &"arcane_taser":
			return &"lightning"
		&"acid_flask", &"toxic_spores":
			return &"toxic"
		&"seismic_crystal":
			return &"seismic"
		&"unstable_void":
			return &"void"
		_:
			return &"ballistic"

static func _projectile_color_for(weapon_id: StringName) -> Color:
	match weapon_id:
		&"heavy_revolver":
			return Color(0.98, 0.78, 0.36, 1.0)
		&"unstable_smg":
			return Color(0.72, 0.93, 1.0, 1.0)
		&"pump_shotgun", &"sawed_off_double":
			return Color(1.0, 0.66, 0.30, 1.0)
		&"tactical_carbine", &"burst_pistol":
			return Color(0.92, 0.82, 0.54, 1.0)
		&"improvised_sniper":
			return Color(0.92, 0.96, 1.0, 1.0)
		&"grenade_launcher":
			return Color(0.82, 0.78, 0.58, 1.0)
		&"rusty_minigun":
			return Color(1.0, 0.86, 0.42, 1.0)
		&"scrap_railgun":
			return Color(0.42, 0.96, 1.0, 1.0)
		&"fire_wand", &"fireball":
			return Color(1.0, 0.34, 0.12, 1.0)
		&"ice_lance", &"frost_nova":
			return Color(0.48, 0.92, 1.0, 1.0)
		&"chain_lightning", &"arcane_taser":
			return Color(1.0, 0.95, 0.24, 1.0)
		&"acid_flask", &"toxic_spores":
			return Color(0.46, 1.0, 0.30, 1.0)
		&"seismic_crystal":
			return Color(0.84, 0.62, 1.0, 1.0)
		&"unstable_void":
			return Color(0.64, 0.28, 1.0, 1.0)
		_:
			return Color(1.0, 0.72, 0.24, 1.0)

static func _projectile_glow_color_for(weapon_id: StringName) -> Color:
	var color := _projectile_color_for(weapon_id)
	match _impact_vfx_for(weapon_id):
		&"void":
			return Color(0.78, 0.38, 1.0, 0.80)
		&"toxic":
			return Color(0.54, 1.0, 0.36, 0.78)
		&"ice":
			return Color(0.62, 0.96, 1.0, 0.74)
		&"rail":
			return Color(0.46, 1.0, 1.0, 0.88)
		_:
			return Color(color.lightened(0.18), 0.72)

static func _muzzle_color_for(weapon_id: StringName) -> Color:
	match _impact_vfx_for(weapon_id):
		&"fire", &"explosive":
			return Color(1.0, 0.50, 0.16, 1.0)
		&"ice":
			return Color(0.70, 0.96, 1.0, 1.0)
		&"lightning":
			return Color(1.0, 0.98, 0.36, 1.0)
		&"toxic":
			return Color(0.56, 1.0, 0.32, 1.0)
		&"seismic":
			return Color(0.92, 0.70, 1.0, 1.0)
		&"void":
			return Color(0.74, 0.34, 1.0, 1.0)
		&"rail":
			return Color(0.48, 1.0, 1.0, 1.0)
		_:
			return Color(1.0, 0.78, 0.26, 1.0)

static func _projectile_scale_for(weapon_id: StringName) -> Vector2:
	match weapon_id:
		&"heavy_revolver":
			return Vector2(1.08, 0.88)
		&"unstable_smg":
			return Vector2(0.62, 0.50)
		&"pump_shotgun":
			return Vector2(0.55, 0.55)
		&"tactical_carbine":
			return Vector2(0.92, 0.62)
		&"improvised_sniper":
			return Vector2(1.34, 0.46)
		&"grenade_launcher":
			return Vector2(1.05, 1.05)
		&"sawed_off_double":
			return Vector2(0.58, 0.68)
		&"burst_pistol":
			return Vector2(0.74, 0.56)
		&"rusty_minigun":
			return Vector2(0.54, 0.42)
		&"scrap_railgun":
			return Vector2(1.62, 0.52)
		&"fire_wand":
			return Vector2(0.92, 0.72)
		&"fireball":
			return Vector2(1.18, 1.18)
		&"ice_lance":
			return Vector2(1.28, 0.58)
		&"frost_nova":
			return Vector2(1.04, 1.04)
		&"chain_lightning":
			return Vector2(1.15, 1.0)
		&"arcane_taser":
			return Vector2(0.86, 0.62)
		&"acid_flask":
			return Vector2(0.96, 0.96)
		&"toxic_spores":
			return Vector2(1.22, 1.08)
		&"seismic_crystal":
			return Vector2(1.16, 1.04)
		&"unstable_void":
			return Vector2(1.24, 1.24)
		_:
			return Vector2.ONE

static func _trail_length_for(weapon_id: StringName) -> float:
	match weapon_id:
		&"unstable_smg", &"pump_shotgun", &"sawed_off_double", &"burst_pistol":
			return 9.0
		&"heavy_revolver", &"tactical_carbine", &"rusty_minigun":
			return 15.0
		&"improvised_sniper":
			return 28.0
		&"scrap_railgun":
			return 36.0
		&"fireball", &"toxic_spores", &"unstable_void":
			return 24.0
		&"chain_lightning", &"ice_lance":
			return 20.0
		_:
			return 16.0

static func _trail_width_for(weapon_id: StringName) -> float:
	match weapon_id:
		&"unstable_smg", &"rusty_minigun", &"pump_shotgun", &"sawed_off_double":
			return 2.4
		&"improvised_sniper", &"scrap_railgun":
			return 5.2
		&"grenade_launcher", &"fireball", &"toxic_spores", &"unstable_void":
			return 6.0
		&"seismic_crystal", &"frost_nova":
			return 5.4
		_:
			return 3.8

static func _muzzle_size_for(weapon_id: StringName) -> float:
	match weapon_id:
		&"unstable_smg":
			return 5.0
		&"heavy_revolver", &"burst_pistol":
			return 7.0
		&"pump_shotgun":
			return 13.0
		&"sawed_off_double":
			return 15.0
		&"tactical_carbine", &"ice_lance", &"acid_flask":
			return 9.0
		&"improvised_sniper", &"rusty_minigun":
			return 10.0
		&"grenade_launcher", &"chain_lightning", &"toxic_spores":
			return 12.0
		&"scrap_railgun", &"unstable_void":
			return 14.0
		&"fire_wand", &"arcane_taser":
			return 8.0
		&"fireball", &"frost_nova", &"seismic_crystal":
			return 13.0
		_:
			return 7.0

static func _rarity_glow_for(rarity: StringName) -> float:
	match rarity:
		&"uncommon":
			return 0.18
		&"rare":
			return 0.32
		&"epic":
			return 0.46
		_:
			return 0.08

static func _rarity_outline_for(rarity: StringName) -> Color:
	match rarity:
		&"uncommon":
			return Color(0.42, 0.90, 1.0, 0.92)
		&"rare":
			return Color(0.70, 0.48, 1.0, 0.95)
		&"epic":
			return Color(1.0, 0.62, 0.16, 0.98)
		_:
			return Color(0.86, 0.92, 0.98, 0.78)
