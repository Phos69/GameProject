extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert_weapon_hitbox(
		"res://game/weapons/rpg_pistol.tres",
		&"circle",
		Vector2(8.0, 8.0),
		1
	)
	_assert_weapon_hitbox(
		"res://game/weapons/rpg_bow.tres",
		&"capsule",
		Vector2(10.0, 28.0),
		1
	)
	_assert_weapon_hitbox(
		"res://game/weapons/rpg_axe.tres",
		&"arc",
		Vector2(90.0, 70.0),
		4
	)
	_assert_weapon_hitbox(
		"res://game/weapons/rpg_sword.tres",
		&"rectangle",
		Vector2(110.0, 45.0),
		3
	)

	var projectile_scene := load("res://game/projectiles/projectile.tscn") as PackedScene
	_expect(projectile_scene != null, "projectile scene can be loaded")
	if projectile_scene == null:
		_finish()
		return
	var projectile := projectile_scene.instantiate() as Projectile
	root.add_child(projectile)
	projectile.launch(
		Vector2.RIGHT,
		1.0,
		null,
		1,
		&"test_arc",
		null,
		80.0,
		&"arc",
		Vector2(90.0, 70.0),
		4
	)
	await process_frame
	var collision_shape := projectile.get_node(
		"CollisionShape2D"
	) as CollisionShape2D
	_expect(
		collision_shape.shape is ConvexPolygonShape2D,
		"arc hitbox creates a convex polygon shape"
	)
	_expect(projectile.max_hit_count == 4, "projectile keeps configured multi-hit count")
	projectile.queue_free()

	_finish()

func _assert_weapon_hitbox(
	path: String,
	expected_type: StringName,
	expected_size: Vector2,
	expected_hits: int
) -> void:
	var weapon := load(path) as WeaponData
	_expect(weapon != null, "%s can be loaded" % path)
	if weapon == null:
		return
	_expect(weapon.hitbox_type == expected_type, "%s hitbox type matches" % weapon.display_name)
	_expect(weapon.hitbox_size == expected_size, "%s hitbox size matches" % weapon.display_name)
	_expect(weapon.max_hit_count == expected_hits, "%s hit count matches" % weapon.display_name)
	if expected_type == &"arc" or expected_type == &"rectangle":
		_expect(
			weapon.uses_melee_attack(),
			"%s resolves through melee attack runtime" % weapon.display_name
		)
		_expect(
			weapon.projectile_scene == null,
			"%s no longer carries a projectile scene" % weapon.display_name
		)
	else:
		_expect(
			weapon.uses_projectile_attack(),
			"%s resolves through projectile runtime" % weapon.display_name
		)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_4_HITBOX_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_4_HITBOX_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
