extends RefCounted
class_name WorldRegionRetirementQueue

## Smaltisce sottoalberi di regioni non piu' attive senza affidare al singolo
## queue_free della root la distruzione ricorsiva di centinaia di nodi nello
## stesso fine-frame. Le root vengono rese invisibili e inattive subito; poi
## si procede dalle foglie verso l'alto con un budget per frame.

var _root_instance_ids: Array[int] = []
var _last_retired_node_count: int = 0
var _last_process_msec: float = 0.0
var _max_process_msec: float = 0.0


func begin_frame() -> void:
	_last_retired_node_count = 0
	_last_process_msec = 0.0


func enqueue(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var instance_id := int(root.get_instance_id())
	if _root_instance_ids.has(instance_id):
		return
	root.process_mode = Node.PROCESS_MODE_DISABLED
	if root is CanvasItem:
		(root as CanvasItem).visible = false
	_root_instance_ids.append(instance_id)


func process(budget_msec: float, max_nodes: int) -> void:
	begin_frame()
	if _root_instance_ids.is_empty():
		return
	var started_usec := Time.get_ticks_usec()
	var safe_budget_msec := maxf(budget_msec, 0.1)
	var safe_max_nodes := maxi(max_nodes, 1)
	while not _root_instance_ids.is_empty():
		if (
			_last_retired_node_count > 0
			and (
				_last_retired_node_count >= safe_max_nodes
				or float(Time.get_ticks_usec() - started_usec) / 1000.0
				>= safe_budget_msec
			)
		):
			break
		var root := instance_from_id(_root_instance_ids[0]) as Node
		if root == null or not is_instance_valid(root):
			_root_instance_ids.remove_at(0)
			continue
		if root.is_queued_for_deletion():
			_root_instance_ids.remove_at(0)
			continue
		if _queue_one_leaf(root):
			_last_retired_node_count += 1
		if root.is_queued_for_deletion():
			_root_instance_ids.remove_at(0)
	_last_process_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	_max_process_msec = maxf(_max_process_msec, _last_process_msec)


func flush() -> void:
	for instance_id in _root_instance_ids:
		var root := instance_from_id(instance_id) as Node
		if (
			root != null
			and is_instance_valid(root)
			and not root.is_queued_for_deletion()
		):
			root.queue_free()
	_root_instance_ids.clear()
	_last_retired_node_count = 0
	_last_process_msec = 0.0


func get_stats() -> Dictionary:
	return {
		"pending_retirement_roots": _root_instance_ids.size(),
		"last_frame_retired_nodes": _last_retired_node_count,
		"last_frame_retirement_msec": _last_process_msec,
		"max_retirement_msec": _max_process_msec
	}


func _queue_one_leaf(node: Node) -> bool:
	for child_value in node.get_children():
		var child := child_value as Node
		if (
			child == null
			or not is_instance_valid(child)
			or child.is_queued_for_deletion()
		):
			continue
		return _queue_one_leaf(child)
	if node.is_queued_for_deletion():
		return false
	node.queue_free()
	return true
