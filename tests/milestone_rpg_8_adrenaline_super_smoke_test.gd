extends SceneTree

var failures: PackedStringArray = []
var projectile_spawn_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root

	var health_system := HealthSystem.new()
	scene_root.add_child(health_system)
	var projectile_system := ProjectileSystem.new()
	scene_root.add_child(projectile_system)
	projectile_system.projectile_spawned.connect(_on_projectile_spawned)

	var player_scene := load("res://game/player/player.tscn") as PackedScene
	var enemy_scene := load("res://game/enemies/basic_enemy.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded")
	_expect(enemy_scene != null, "enemy scene can be loaded")
	if player_scene == null or enemy_scene == null:
		_finish()
		return

	var player := player_scene.instantiate() as PlayerController
	player.global_position = Vector2.ZERO
	scene_root.add_child(player)
	await process_frame
	await process_frame

	var rpg_component := player.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	var player_health := player.get_node("HealthComponent") as HealthComponent
	_expect(rpg_component != null, "rpg component is available")
	_expect(player_health != null, "player health is available")
	if rpg_component == null or player_health == null:
		_finish()
		return

	player.apply_rpg_character(&"ranger")
	var hit_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(140.0, 0.0))
	await process_frame
	var start_adrenaline := rpg_component.adrenaline
	health_system.apply_damage(hit_enemy, 3, player, &"test_hit")
	_expect(rpg_component.adrenaline > start_adrenaline, "damage dealt grants adrenaline")
	var after_dealt := rpg_component.adrenaline
	health_system.apply_damage(player, 3, hit_enemy, &"test_taken")
	_expect(rpg_component.adrenaline > after_dealt, "damage taken grants adrenaline")

	player.apply_rpg_character(&"ranger")
	var kill_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(180.0, 0.0))
	await process_frame
	health_system.apply_damage(kill_enemy, 9999, player, &"test_kill")
	_expect(rpg_component.adrenaline >= 6, "kill grants hit and kill adrenaline")

	player.apply_rpg_character(&"pistoliere")
	rpg_component.add_adrenaline(90)
	rpg_component.notify_wave_completed()
	_expect(rpg_component.is_super_ready(), "wave adrenaline can ready the super")

	player.apply_rpg_character(&"ranger")
	rpg_component.add_adrenaline(100)
	projectile_spawn_count = 0
	var arrow_rain_used := rpg_component.try_activate_super(Vector2.RIGHT)
	_expect(arrow_rain_used, "ranger super activates")
	_expect(rpg_component.adrenaline == 0, "super activation spends adrenaline")
	_expect(projectile_spawn_count == 12, "arrow rain spawns twelve projectiles")

	player.apply_rpg_character(&"pistoliere")
	_spawn_enemy(scene_root, enemy_scene, Vector2(220.0, 0.0))
	await process_frame
	projectile_spawn_count = 0
	rpg_component.add_adrenaline(100)
	var barrage_used := rpg_component.try_activate_super(Vector2.RIGHT)
	_expect(barrage_used, "pistoliere super activates")
	_expect(rpg_component.final_barrage_timer > 0.0, "final barrage keeps an active timer")
	_expect(projectile_spawn_count >= 1, "final barrage fires immediately")

	player.apply_rpg_character(&"berserker")
	player.global_position = Vector2.ZERO
	var quake_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(70.0, 0.0))
	await process_frame
	var quake_health := quake_enemy.health_component.current_health
	rpg_component.add_adrenaline(100)
	var quake_used := rpg_component.try_activate_super(Vector2.RIGHT)
	_expect(quake_used, "berserker super activates")
	_expect(
		quake_enemy.health_component.current_health < quake_health,
		"blood quake damages nearby enemies"
	)

	player.apply_rpg_character(&"spadaccino")
	player.global_position = Vector2.ZERO
	var blade_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(110.0, 0.0))
	await process_frame
	var blade_health := blade_enemy.health_component.current_health
	var start_position := player.global_position
	player_health.invulnerable = false
	rpg_component.add_adrenaline(100)
	var blade_used := rpg_component.try_activate_super(Vector2.RIGHT)
	_expect(blade_used, "spadaccino super activates")
	_expect(
		player.global_position.distance_to(start_position) > 120.0,
		"phantom blade moves the player forward"
	)
	_expect(player_health.invulnerable, "phantom blade grants brief invulnerability")
	_expect(
		blade_enemy.health_component.current_health < blade_health,
		"phantom blade damages enemies in the dash path"
	)
	rpg_component.super_invulnerable_timer = 0.02
	for _frame in range(60):
		if not player_health.invulnerable:
			break
		await process_frame
	_expect(not player_health.invulnerable, "phantom blade invulnerability recovers")

	scene_root.queue_free()
	_finish()

func _spawn_enemy(
	parent: Node,
	enemy_scene: PackedScene,
	position: Vector2
) -> BasicEnemy:
	var enemy := enemy_scene.instantiate() as BasicEnemy
	enemy.global_position = position
	parent.add_child(enemy)
	return enemy

func _on_projectile_spawned(_projectile: Node) -> void:
	projectile_spawn_count += 1

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_8_ADRENALINE_SUPER_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_8_ADRENALINE_SUPER_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
