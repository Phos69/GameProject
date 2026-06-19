extends RefCounted
class_name WeaponCatalog

const PROJECTILE_SCENE: PackedScene = preload("res://game/projectiles/projectile.tscn")
const FIREARM_VISUAL: WeaponVisualData = preload("res://game/weapons/prototype_blaster_visual.tres")
const MELEE_VISUAL: WeaponVisualData = preload("res://game/weapons/rpg_sword_visual.tres")
const ELEMENTAL_VISUAL: WeaponVisualData = preload("res://game/weapons/wave_cannon_visual.tres")

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
	match definition.category:
		&"melee": definition.visual_data = MELEE_VISUAL
		&"elemental": definition.visual_data = ELEMENTAL_VISUAL
		_: definition.visual_data = FIREARM_VISUAL
	return definition
