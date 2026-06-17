extends SceneTree

const ITERATIONS := 100
const MAIN_SCENE_PATH := "res://game/main/main.tscn"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		push_error("Unable to load %s" % MAIN_SCENE_PATH)
		quit(1)
		return
	for index in range(ITERATIONS):
		var instance := main_scene.instantiate()
		if instance == null:
			failures.append("instantiate failed at iteration %d" % (index + 1))
			break
		root.add_child(instance)
		current_scene = instance
		await process_frame
		await process_frame
		_teardown_scene(instance)
		await process_frame
		await process_frame
	if failures.is_empty():
		print("HEADLESS_SHUTDOWN_LOOP_TEST: PASS %d cycles" % ITERATIONS)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _teardown_scene(instance: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	if current_scene == instance:
		current_scene = null
	if instance.get_parent() != null:
		instance.get_parent().remove_child(instance)
	instance.free()
