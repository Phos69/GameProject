extends SceneTree

func _initialize() -> void:
	var scene_root := Node2D.new(); scene_root.name = "StatusSmokeRoot"; scene_root.add_to_group("players"); root.add_child(scene_root); current_scene = scene_root; scene_root.add_child(HealthSystem.new())
	var player := Node2D.new(); player.name = "Player"; player.add_to_group("players"); scene_root.add_child(player)
	var health := HealthComponent.new(); health.name = "HealthComponent"; health.max_health = 100; health.current_health = 100; player.add_child(health)
	var runtime := BiomeStatusRuntime.new()
	for id in [&"poison", &"burn", &"bleed", &"freeze", &"shock"]:
		_assert(runtime.apply_status(player, id, 1.0, 1.0, null, []), "applies %s" % id)
		_assert(runtime.has_status(player, id), "has %s" % id)
	runtime.process_runtime(1.2, self, [])
	for id in [&"poison", &"burn", &"bleed", &"freeze", &"shock"]:
		_assert(not runtime.has_status(player, id), "cleans %s" % id)
	print("biome_status_effects_smoke_test passed")
	quit(0)

func _assert(ok: bool, message: String) -> void:
	if not ok:
		push_error(message); quit(1)
