extends RefCounted
class_name TestSceneLifecycle

static func teardown_current_scene(tree: SceneTree, frames: int = 3) -> void:
	if tree == null:
		return
	for _index in range(maxi(frames, 0)):
		await tree.process_frame
	var scene := tree.current_scene
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
		tree.current_scene = null
	for _index in range(maxi(frames, 0)):
		await tree.process_frame
	if scene != null and is_instance_valid(scene):
		scene.free()
