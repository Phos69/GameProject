extends GutTest
## Enemies - Contratto del roster boss zombie, pattern e hitbox ostili.

const ZOMBIE_BOSSES: Array[Dictionary] = [
	{
		"boss_id": &"grave_colossus",
		"scene_path": "res://game/bosses/zombie/grave_colossus.tscn",
		"patterns": [&"cleaver_sweep", &"grave_slam"]
	},
	{
		"boss_id": &"gore_charger",
		"scene_path": "res://game/bosses/zombie/gore_charger.tscn",
		"patterns": [&"gore_charge", &"horn_combo"]
	},
	{
		"boss_id": &"plague_spitter",
		"scene_path": "res://game/bosses/zombie/plague_spitter.tscn",
		"patterns": [&"plague_fan", &"spore_ring"]
	},
	{
		"boss_id": &"bone_mortar",
		"scene_path": "res://game/bosses/zombie/bone_mortar.tscn",
		"patterns": [&"bone_mortar", &"bone_shards"]
	},
	{
		"boss_id": &"carrion_shepherd",
		"scene_path": "res://game/bosses/zombie/carrion_shepherd.tscn",
		"patterns": [&"carrion_bolt", &"butcher_sweep"]
	}
]

var _pattern_emission_count: int = 0

func test_zombie_boss_registry_modes_are_explicit() -> void:
	var boss_system := BossSystem.new()
	add_child_autofree(boss_system)
	var registered_ids := boss_system.get_registered_boss_ids()
	for definition in ZOMBIE_BOSSES:
		var boss_id := StringName(definition.get("boss_id", &""))
		assert_has(registered_ids, boss_id, "%s is registered" % String(boss_id))
		assert_true(
			boss_system.is_boss_compatible(
				boss_id,
				GameConstants.MODE_INFINITE_ARENA
			),
			"%s supports Infinite Arena" % String(boss_id)
		)
		assert_true(
			boss_system.is_boss_compatible(
				boss_id,
				GameConstants.MODE_SURVIVAL
			),
			"%s supports Survival" % String(boss_id)
		)
		assert_false(
			boss_system.is_boss_compatible(
				boss_id,
				GameConstants.MODE_DUNGEON
			),
			"%s rejects Dungeon" % String(boss_id)
		)
		assert_false(
			boss_system.is_boss_compatible(
				boss_id,
				GameConstants.MODE_TOWER_DEFENSE
			),
			"%s rejects Tower Defense" % String(boss_id)
		)
		var compatible_modes: Array = boss_system.boss_compatible_modes.get(
			boss_id,
			[]
		)
		assert_eq(
			compatible_modes.size(),
			2,
			"%s exposes only the two supported modes" % String(boss_id)
		)

func test_survival_boss_rotation_waves_five_through_thirty() -> void:
	var survival_mode := SurvivalMode.new()
	var boss_waves: Array[int] = [5, 10, 15, 20, 25, 30]
	var expected_ids: Array[StringName] = [
		&"wave_warden",
		&"grave_colossus",
		&"gore_charger",
		&"plague_spitter",
		&"bone_mortar",
		&"carrion_shepherd"
	]
	for index in range(boss_waves.size()):
		assert_eq(
			survival_mode.get_boss_id_for_wave(boss_waves[index]),
			expected_ids[index],
			"wave %d selects %s" % [
				boss_waves[index],
				String(expected_ids[index])
			]
		)
	assert_eq(
		survival_mode.get_boss_id_for_wave(6),
		&"",
		"a non-boss wave has no boss id"
	)
	survival_mode.free()

func test_zombie_boss_scenes_share_the_runtime_contract() -> void:
	var movement_styles: Dictionary = {}
	var shared_loot := load("res://game/drops/boss_loot.tres") as LootTable
	assert_not_null(shared_loot, "shared boss loot loads")
	for definition in ZOMBIE_BOSSES:
		var boss_id := StringName(definition.get("boss_id", &""))
		var scene_path := String(definition.get("scene_path", ""))
		var packed := load(scene_path) as PackedScene
		assert_not_null(packed, "%s scene loads" % String(boss_id))
		if packed == null:
			continue
		var instance := packed.instantiate()
		assert_true(
			instance is ZombieBossBase,
			"%s extends ZombieBossBase" % String(boss_id)
		)
		if not instance is ZombieBossBase:
			instance.free()
			continue
		var boss := instance as ZombieBossBase
		boss.set_physics_process(false)
		add_child(boss)
		assert_eq(boss.boss_id, boss_id, "%s preserves its scene id" % String(boss_id))
		assert_false(
			boss.display_name.is_empty(),
			"%s has a display name" % String(boss_id)
		)
		assert_true(
			boss.is_in_group("bosses") and boss.is_in_group("zombie_bosses"),
			"%s joins the shared boss groups" % String(boss_id)
		)
		assert_true(
			boss.loot_table == shared_loot,
			"%s uses the shared boss loot" % String(boss_id)
		)
		var health := boss.get_node_or_null("HealthComponent") as HealthComponent
		var visual := boss.get_node_or_null("Visual") as ZombieBossVisual
		var telegraph := boss.get_node_or_null(
			"TelegraphVisual"
		) as BossTelegraphVisual
		var collision := boss.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
		assert_true(
			health != null and health.max_health > 0,
			"%s has a positive health pool" % String(boss_id)
		)
		assert_true(
			visual != null and visual.get_profile_id() == boss_id,
			"%s has its dedicated visual profile" % String(boss_id)
		)
		assert_not_null(
			telegraph,
			"%s has the shared telegraph visual" % String(boss_id)
		)
		assert_true(
			collision != null and collision.shape != null,
			"%s has a body collision" % String(boss_id)
		)
		var movement_style := boss.get_movement_style_id()
		assert_false(
			movement_style.is_empty(),
			"%s declares a movement style" % String(boss_id)
		)
		assert_false(
			movement_styles.has(movement_style),
			"%s movement style is distinct" % String(boss_id)
		)
		movement_styles[movement_style] = boss_id
		boss.free()
	assert_eq(movement_styles.size(), 5, "all five movement contracts are distinct")

func test_all_patterns_have_distinct_harmless_telegraphs() -> void:
	var target := _make_health_target(
		&"players",
		Vector2(280.0, 0.0),
		"TelegraphTarget"
	)
	var target_health := target.get_node("HealthComponent") as HealthComponent
	var seen_patterns: Dictionary = {}
	for definition in ZOMBIE_BOSSES:
		var boss_id := StringName(definition.get("boss_id", &""))
		var packed := load(String(definition.get("scene_path", ""))) as PackedScene
		if packed == null:
			assert_not_null(packed, "%s scene loads for pattern checks" % String(boss_id))
			continue
		var boss := packed.instantiate() as ZombieBossBase
		assert_not_null(boss, "%s instantiates for pattern checks" % String(boss_id))
		if boss == null:
			continue
		boss.global_position = Vector2.ZERO
		boss.move_speed = 0.0
		boss.attack_timer = 100.0
		add_child(boss)
		boss.target = target
		boss.attack_pattern_started.connect(_on_attack_pattern_started)
		var patterns: Array = definition.get("patterns", [])
		assert_eq(patterns.size(), 2, "%s exposes two patterns" % String(boss_id))
		for pattern_value in patterns:
			var pattern_id := StringName(pattern_value)
			assert_false(
				seen_patterns.has(pattern_id),
				"%s is unique in the roster" % String(pattern_id)
			)
			seen_patterns[pattern_id] = boss_id
			_pattern_emission_count = 0
			var health_before := target_health.current_health
			var damage_nodes_before := _count_damage_nodes(get_tree().root)
			assert_true(
				boss.start_attack_telegraph(pattern_id),
				"%s starts its telegraph" % String(pattern_id)
			)
			assert_eq(
				boss.pending_pattern_id,
				pattern_id,
				"%s is pending during its warning" % String(pattern_id)
			)
			assert_true(
				boss.telegraph_visual.is_telegraph_active()
					and boss.telegraph_visual.active_pattern == pattern_id,
				"%s exposes its world-space warning" % String(pattern_id)
			)
			await wait_physics_frames(2)
			assert_eq(
				target_health.current_health,
				health_before,
				"%s warning is harmless" % String(pattern_id)
			)
			assert_eq(
				_pattern_emission_count,
				0,
				"%s emits no attack during its warning" % String(pattern_id)
			)
			assert_eq(
				_count_damage_nodes(get_tree().root),
				damage_nodes_before,
				"%s creates no damaging node during its warning" % String(pattern_id)
			)
			boss.cancel_attack_telegraph()
		boss.free()
	assert_eq(seen_patterns.size(), 10, "the roster exposes ten distinct patterns")

func test_hostile_melee_hits_only_players_once() -> void:
	var packed := load(
		"res://game/bosses/zombie/grave_colossus.tscn"
	) as PackedScene
	assert_not_null(packed, "Grave Colossus scene loads for melee contract")
	if packed == null:
		return
	var boss := packed.instantiate() as GraveColossus
	assert_not_null(boss, "Grave Colossus instantiates for melee contract")
	if boss == null:
		return
	boss.global_position = Vector2(900.0, 900.0)
	boss.melee_damage = 13
	boss.damage_multiplier = 1.0
	boss.set_physics_process(false)
	add_child(boss)

	var blocked_player := _make_health_target(
		&"players",
		boss.global_position + Vector2(180.0, 0.0),
		"InvulnerablePlayerTarget"
	)
	var vulnerable_player := _make_health_target(
		&"players",
		boss.global_position + Vector2(180.0, 24.0),
		"VulnerablePlayerTarget"
	)
	var non_player := _make_health_target(
		&"damageable_targets",
		boss.global_position + Vector2(34.0, 0.0),
		"NonPlayerTarget"
	)
	var blocked_health := blocked_player.get_node(
		"HealthComponent"
	) as HealthComponent
	var player_health := vulnerable_player.get_node(
		"HealthComponent"
	) as HealthComponent
	var non_player_health := non_player.get_node(
		"HealthComponent"
	) as HealthComponent
	blocked_health.invulnerable = true
	watch_signals(blocked_health)
	watch_signals(player_health)
	watch_signals(non_player_health)
	var attack := boss.spawn_hostile_melee(
		&"hostile_melee_contract",
		Vector2.RIGHT,
		&"circle",
		80.0,
		160.0,
		360.0,
		1.0,
		1.0,
		0.0,
		1,
		&"ground_slam"
	)
	assert_not_null(attack, "boss spawns a hostile melee runtime")
	if attack == null:
		boss.free()
		return
	assert_eq(attack.target_group, &"players", "hostile melee targets only players")
	assert_eq(
		attack.target_collision_mask,
		GameConstants.LAYER_BODIES,
		"hostile melee scans the player body layer"
	)
	blocked_player.global_position = boss.global_position + Vector2(32.0, 0.0)
	attack._try_hit_target(blocked_player)
	assert_eq(
		blocked_health.current_health,
		100,
		"an invulnerable player takes no damage"
	)
	assert_eq(
		attack.successful_hit_count,
		0,
		"a zero-damage player does not consume max_hits"
	)
	assert_eq(
		attack.phase,
		MeleeAttack.Phase.ACTIVE,
		"the hitbox remains active after a blocked hit"
	)
	vulnerable_player.global_position = boss.global_position + Vector2(32.0, 0.0)
	attack._try_hit_target(vulnerable_player)
	assert_eq(
		player_health.current_health,
		100 - boss.get_scaled_melee_damage(),
		"the second, vulnerable player still receives the available hit"
	)
	assert_eq(
		non_player_health.current_health,
		100,
		"a non-player damageable target is ignored"
	)
	assert_signal_emit_count(
		player_health,
		"damaged",
		1,
		"the vulnerable player receives exactly one hit"
	)
	assert_signal_not_emitted(
		blocked_health,
		"damaged",
		"the invulnerable player emits no damage event"
	)
	assert_signal_not_emitted(
		non_player_health,
		"damaged",
		"hostile melee never damages a non-player"
	)
	await wait_physics_frames(1)
	blocked_player.global_position = boss.global_position + Vector2(180.0, 0.0)
	vulnerable_player.global_position = boss.global_position + Vector2(180.0, 24.0)
	var cancellable_attack := boss.spawn_hostile_melee(
		&"boss_death_cleanup_contract",
		Vector2.RIGHT,
		&"circle",
		80.0,
		160.0,
		360.0,
		1.0,
		5.0,
		0.0,
		1,
		&"ground_slam"
	)
	assert_true(
		is_instance_valid(cancellable_attack)
			and cancellable_attack.phase == MeleeAttack.Phase.ACTIVE,
		"a long hostile swing is active before boss death"
	)
	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	boss_health.apply_damage(boss_health.current_health)
	await wait_physics_frames(2)
	assert_false(
		is_instance_valid(cancellable_attack),
		"boss death frees its active melee swing"
	)
	assert_false(is_instance_valid(boss), "the defeated boss is freed")

func _make_health_target(
	group_id: StringName,
	position: Vector2,
	node_name: String
) -> CharacterBody2D:
	var target := CharacterBody2D.new()
	target.name = node_name
	target.global_position = position
	target.add_to_group(group_id)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100
	target.add_child(health)
	add_child_autofree(target)
	return target

func _count_damage_nodes(root: Node) -> int:
	var result := 1 if root is MeleeAttack or root is Projectile else 0
	for child in root.get_children():
		result += _count_damage_nodes(child)
	return result

func _on_attack_pattern_started(
	_pattern_id: StringName,
	_projectile_count: int
) -> void:
	_pattern_emission_count += 1
