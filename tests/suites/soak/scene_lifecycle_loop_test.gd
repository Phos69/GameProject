extends GutTest
## Soak/Stress — Loop di boot/teardown di main.tscn (stabilità del lifecycle).
##
## Migra:
##   tests/headless_shutdown_loop_test.gd  (100 cicli di instantiate/free di main.tscn)
##
## NB: suite di stress, esclusa dal run rapido (.gutconfig.json). Verifica che 100
## cicli di costruzione/distruzione della scena principale non lascino riferimenti
## penzolanti o crash in headless.

const ITERATIONS := 100
const MAIN_SCENE_PATH := "res://game/main/main.tscn"

func test_repeated_scene_lifecycle() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	assert_not_null(main_scene, "main scene can be loaded")
	if main_scene == null:
		return
	var completed := 0
	for index in range(ITERATIONS):
		var instance := main_scene.instantiate()
		if instance == null:
			assert_true(false, "instantiate failed at iteration %d" % (index + 1))
			break
		get_tree().root.add_child(instance)
		get_tree().current_scene = instance
		await wait_frames(2)
		_teardown_scene(instance)
		await wait_frames(2)
		completed += 1
	assert_eq(completed, ITERATIONS, "all %d boot/teardown cycles complete" % ITERATIONS)

func _teardown_scene(instance: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	if get_tree().current_scene == instance:
		get_tree().current_scene = null
	if instance.get_parent() != null:
		instance.get_parent().remove_child(instance)
	instance.free()
