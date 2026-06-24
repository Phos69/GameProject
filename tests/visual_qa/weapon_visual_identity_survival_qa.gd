extends RefCounted

const OUTPUT_DIRECTORY := "res://build/qa"
const PLAYER_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver", &"pump_shotgun", &"demolition_hammer", &"unstable_void"
]
const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie", &"survival_runner", &"survival_tank", &"survival_shooter"
]
const PROFILE_SPECS: Array[Array] = [
	[&"default", "weapon_visual_identity_crowded_default.png"],
	[&"reduced_motion", "weapon_visual_identity_crowded_reduced_motion.png"],
	[&"high_contrast", "weapon_visual_identity_crowded_high_contrast.png"],
]

var failures: PackedStringArray = []

func run(tree: SceneTree, pickup_scene: PackedScene) -> PackedStringArray:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for crowded W7 QA")
	if main_scene == null:
		return failures
	var main := main_scene.instantiate()
	tree.root.add_child(main)
	tree.current_scene = main
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var visual_settings := tree.get_first_node_in_group(
		"visual_settings_manager"
	) as VisualSettingsManager
	var game_mode_manager := tree.get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var local_multiplayer := tree.get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := tree.get_first_node_in_group("player_manager") as PlayerManager
	var wave_manager := tree.get_first_node_in_group("wave_manager") as WaveManager
	var enemy_system := tree.get_first_node_in_group("enemy_system") as EnemySystem
	var projectile_system := tree.get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	_expect(visual_settings != null, "visual settings are available in crowded QA")
	_expect(game_mode_manager != null, "game mode manager is available in crowded QA")
	_expect(local_multiplayer != null, "local multiplayer is available in crowded QA")
	_expect(player_manager != null, "player manager is available in crowded QA")
	_expect(wave_manager != null, "wave manager is available in crowded QA")
	_expect(enemy_system != null, "enemy system is available in crowded QA")
	_expect(projectile_system != null, "projectile system is available in crowded QA")
	if (
		visual_settings == null or game_mode_manager == null
		or local_multiplayer == null or player_manager == null
		or wave_manager == null or enemy_system == null or projectile_system == null
	):
		main.queue_free()
		return failures
	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await tree.process_frame
	await tree.process_frame
	_configure_players(player_manager)
	_spawn_enemies(enemy_system)
	var pickup_parent := main.get_node_or_null("World/Pickups")
	_spawn_pickups(pickup_parent, pickup_scene)
	_spawn_projectiles(projectile_system)
	var profile_hashes: Dictionary = {}
	for profile_spec in PROFILE_SPECS:
		var profile_id := profile_spec[0] as StringName
		var file_name := str(profile_spec[1])
		_expect(
			visual_settings.apply_profile(profile_id),
			"%s visual profile applies in crowded QA" % profile_id
		)
		await tree.process_frame
		await tree.process_frame
		_validate_profile_consumers(profile_id, player_manager, pickup_parent)
		var image := await _capture_image(tree, file_name)
		_expect(_is_nonempty_image(image), "%s crowded screenshot is non-empty" % profile_id)
		if image != null:
			profile_hashes[hash(image.get_data())] = profile_id
	_expect(profile_hashes.size() >= 2, "visual presets produce measurably different frames")
	main.queue_free()
	await tree.process_frame
	tree.current_scene = null
	return failures

func _configure_players(player_manager: PlayerManager) -> void:
	var positions: Array[Vector2] = [
		Vector2(-150.0, 80.0), Vector2(-50.0, 112.0),
		Vector2(50.0, 112.0), Vector2(150.0, 80.0)
	]
	for slot in range(1, 5):
		var player := player_manager.players.get(slot) as PlayerController
		_expect(player != null, "crowded QA player %d exists" % slot)
		if player == null:
			continue
		player.global_position = positions[slot - 1]
		player.set_physics_process(false)
		player.facing_direction = Vector2(0.86, -0.36).rotated(float(slot - 2) * 0.20)
		player.visual.set_facing(player.facing_direction)
		var definition := WeaponCatalog.get_definition(PLAYER_WEAPON_IDS[slot - 1])
		_expect(
			definition != null and player.weapon_system.equip_weapon(definition),
			"player %d equips %s" % [slot, PLAYER_WEAPON_IDS[slot - 1]]
		)

func _spawn_enemies(enemy_system: EnemySystem) -> void:
	var positions: Array[Vector2] = [
		Vector2(-300.0, -90.0), Vector2(-210.0, -150.0),
		Vector2(-110.0, -190.0), Vector2(0.0, -205.0),
		Vector2(110.0, -190.0), Vector2(210.0, -150.0),
		Vector2(300.0, -90.0), Vector2(0.0, -70.0)
	]
	var spawned := 0
	for index in range(positions.size()):
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()], positions[index]
		)
		if enemy != null:
			spawned += 1
			enemy.set_physics_process(false)
	_expect(spawned == positions.size(), "crowded QA spawns eight zombies")

func _spawn_pickups(parent: Node, pickup_scene: PackedScene) -> void:
	var ids: Array[StringName] = [
		&"heavy_revolver", &"pump_shotgun", &"quick_knife",
		&"demolition_hammer", &"fireball", &"ice_lance"
	]
	var count := 0
	if parent != null:
		for index in range(ids.size()):
			var definition := WeaponCatalog.get_definition(ids[index])
			var pickup := pickup_scene.instantiate() as DropPickup
			pickup.setup({
				"type": GameConstants.DROP_WEAPON,
				"amount": 1,
				"weapon_data": definition
			})
			pickup.position = Vector2(-235.0 + float(index) * 94.0, 205.0)
			parent.add_child(pickup)
			count += 1
	_expect(count == 6, "crowded QA includes six weapon pickups")

func _spawn_projectiles(projectile_system: ProjectileSystem) -> void:
	var ids: Array[StringName] = [
		&"heavy_revolver", &"pump_shotgun", &"fireball", &"ice_lance", &"unstable_void"
	]
	var count := 0
	for index in range(ids.size()):
		var definition := WeaponCatalog.get_definition(ids[index])
		var projectile := projectile_system.spawn_projectile(
			Vector2(-210.0 + float(index) * 105.0, -20.0),
			Vector2.RIGHT,
			0.0,
			null,
			null,
			1,
			definition.weapon_id,
			definition.visual_data
		) as Projectile
		if projectile != null:
			projectile.lifetime = 30.0
			projectile.set_physics_process(false)
			count += 1
	_expect(count == 5, "crowded QA includes five distinct projectiles")

func _validate_profile_consumers(
	profile_id: StringName,
	player_manager: PlayerManager,
	pickup_parent: Node
) -> void:
	var player := player_manager.players.get(1) as PlayerController
	if player == null:
		failures.append("profile validation player missing")
		return
	match profile_id:
		&"reduced_motion":
			_expect(player.visual.reduced_motion, "reduced motion reaches held weapon visual")
		&"high_contrast":
			_expect(player.visual.high_contrast, "high contrast reaches held weapon visual")
		&"default":
			_expect(
				not player.visual.reduced_motion and not player.visual.high_contrast,
				"default profile restores held weapon presentation"
			)
	var pickup := _first_weapon_pickup(pickup_parent)
	if pickup == null or pickup.visual == null:
		failures.append("profile validation pickup visual missing")
		return
	if profile_id == &"reduced_motion":
		_expect(pickup.visual.reduced_motion, "reduced motion reaches weapon pickups")
	elif profile_id == &"high_contrast":
		_expect(pickup.visual.high_contrast, "high contrast reaches weapon pickups")

func _first_weapon_pickup(parent: Node) -> DropPickup:
	if parent == null:
		return null
	for child in parent.get_children():
		if child is DropPickup:
			var candidate := child as DropPickup
			if StringName(candidate.drop_data.get("type", &"")) == GameConstants.DROP_WEAPON:
				return candidate
	return null

func _capture_image(tree: SceneTree, file_name: String) -> Image:
	await tree.process_frame
	var image := tree.root.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	var output_path := ProjectSettings.globalize_path(
		"%s/%s" % [OUTPUT_DIRECTORY, file_name]
	)
	_expect(image.save_png(output_path) == OK, "%s screenshot is saved" % file_name)
	return image

func _is_nonempty_image(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var visible_samples := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.16:
				visible_samples += 1
	return visible_samples > 200

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)
