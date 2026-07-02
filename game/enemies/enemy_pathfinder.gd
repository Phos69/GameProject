extends RefCounted
class_name EnemyPathfinder

## Grid A* navigator shared by enemy AI. Runs entirely in world space: the
## impassability queries (ObstacleSystem / HazardSystem) already accept world
## coordinates and are streaming-aware, so no region/tile coupling is needed.
##
## AI levels (extensible):
##   level 0 -> path avoids obstacles only (pits stay traversable; enemy can
##              walk into a pit and fall, handled by HazardSystem)
##   level 1 -> path also avoids pits (void / fall zones)
##
## Cost control (many enemies path at once):
##   * The expensive decision (obstacle probing / A*) runs at AI_TICK_INTERVAL,
##     not every physics frame; steering toward the chosen aim point is still
##     recomputed every frame so motion stays smooth.
##   * Each instance starts with a deterministic phase offset (from its
##     instance id), so enemies spawned the same frame spread their ticks over
##     different frames instead of paying probe/A* all together forever
##     (measured ~85ms synced spikes with 24 mobs before de-phasing: see
##     tests/suites/soak/perf_bottleneck_stress_test.gd). Until the first tick
##     fires (<= AI_TICK_INTERVAL after spawn) the chase steers straight at the
##     target, same as the "no route within budget" fallback.
##   * The line-of-sight probe is bounded to probe_distance ahead, so open-field
##     chases only sample a handful of cells per tick.
##   * A* is bounded (MAX_EXPANSIONS) and, when the goal is out of budget, returns
##     a partial path toward the closest reached cell so the enemy keeps progress.

const MAX_EXPANSIONS: int = 192
const AI_TICK_INTERVAL: float = 0.1
const RECOMPUTE_INTERVAL: float = 0.35
const WAYPOINT_REACHED_DISTANCE: float = 10.0
const PATH_LOOKAHEAD: int = 4
const DIAGONAL_COST: float = 1.4142135623730951
const _NO_GOAL_CELL := Vector2i(2147483647, 2147483647)
const _NEIGHBOR_OFFSETS: Array = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]

## World size of one pathfinding cell (~1 logical tile at the current iso scale). Coarse enough
## to keep node counts low, fine enough to route around obstacle footprints.
var grid_step: float = 48.0
## How far ahead the straight-line probe looks each tick (~3 cells).
var probe_distance: float = 144.0

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _recompute_cooldown: float = 0.0
var _ai_tick_cooldown: float = 0.0
var _goal_cell: Vector2i = _NO_GOAL_CELL
var _aim_point: Vector2 = Vector2.ZERO
var _aim_is_target: bool = true
var _has_aim: bool = false

func _init() -> void:
	# Fase deterministica per-istanza (niente RNG condiviso): distribuisce il
	# primo tick, e quindi tutti i successivi, nell'intervallo (0, 0.1s].
	var phase := float(posmod(get_instance_id(), 97) + 1) / 98.0
	_ai_tick_cooldown = AI_TICK_INTERVAL * phase

func desired_direction(
	from: Vector2,
	to: Vector2,
	level: int,
	delta: float,
	obstacle_system: Object,
	hazard_system: Object
) -> Vector2:
	_ai_tick_cooldown = maxf(_ai_tick_cooldown - delta, 0.0)
	_recompute_cooldown = maxf(_recompute_cooldown - delta, 0.0)
	if _ai_tick_cooldown <= 0.0:
		_ai_tick_cooldown = AI_TICK_INTERVAL
		_evaluate_aim(from, to, level, obstacle_system, hazard_system)
		_has_aim = true
	# Prima del primo tick (defasato) non c'e' ancora un aim: dritto al target,
	# come il fallback "no route within budget".
	if not _has_aim:
		return _safe_direction(from, to)
	# Steer live toward the target when a straight shot is clear (zero lag); when
	# routing around geometry, steer toward the fixed waypoint chosen this tick.
	if _aim_is_target:
		return _safe_direction(from, to)
	return _safe_direction(from, _aim_point)

func _evaluate_aim(
	from: Vector2,
	to: Vector2,
	level: int,
	obstacle_system: Object,
	hazard_system: Object
) -> void:
	# Common case: the next stretch toward the target is clear -> go straight.
	if _direct_los(from, to, level, obstacle_system, hazard_system):
		_clear_path()
		_aim_is_target = true
		return

	var goal_cell := _world_to_cell(to)
	if (
		_path.is_empty()
		or _path_index >= _path.size()
		or _recompute_cooldown <= 0.0
		or goal_cell != _goal_cell
	):
		_recompute(from, to, level, obstacle_system, hazard_system)

	if _path.is_empty():
		# No route within budget: press toward the target and let move_and_slide
		# handle the collision (matches the legacy behaviour).
		_aim_is_target = true
		return

	_aim_point = _next_path_point(from, to, level, obstacle_system, hazard_system)
	_aim_is_target = false

func _direct_los(
	from: Vector2,
	to: Vector2,
	level: int,
	obstacle_system: Object,
	hazard_system: Object
) -> bool:
	var dist := from.distance_to(to)
	var probe_to := to
	if dist > probe_distance:
		probe_to = from + (to - from) / dist * probe_distance
	return _segment_traversable(from, probe_to, level, obstacle_system, hazard_system)

func _next_path_point(
	from: Vector2,
	to: Vector2,
	level: int,
	obstacle_system: Object,
	hazard_system: Object
) -> Vector2:
	while (
		_path_index < _path.size()
		and from.distance_to(_path[_path_index]) <= WAYPOINT_REACHED_DISTANCE
	):
		_path_index += 1
	if _path_index >= _path.size():
		_clear_path()
		return to
	# Bounded line-of-sight smoothing: aim at the farthest of the next few
	# waypoints still reachable in a straight line, so the enemy cuts corners.
	var last := mini(_path_index + PATH_LOOKAHEAD, _path.size() - 1)
	for i in range(last, _path_index, -1):
		if _segment_traversable(from, _path[i], level, obstacle_system, hazard_system):
			return _path[i]
	return _path[_path_index]

func _recompute(
	from: Vector2,
	to: Vector2,
	level: int,
	obstacle_system: Object,
	hazard_system: Object
) -> void:
	_recompute_cooldown = RECOMPUTE_INTERVAL
	_clear_path()
	var start_cell := _world_to_cell(from)
	var goal_cell := _world_to_cell(to)
	_goal_cell = goal_cell
	if start_cell == goal_cell:
		return

	var blocked_cache := {}
	var came_from := {}
	var g_score := {start_cell: 0.0}
	var closed := {}
	var heap: Array = []
	var best_cell := start_cell
	var best_h := _heuristic(start_cell, goal_cell)
	_heap_push(heap, best_h, start_cell)
	var expansions := 0

	while not heap.is_empty() and expansions < MAX_EXPANSIONS:
		var current: Vector2i = _heap_pop(heap)["cell"]
		if current == goal_cell:
			break
		if closed.has(current):
			continue
		closed[current] = true
		expansions += 1
		var current_h := _heuristic(current, goal_cell)
		if current_h < best_h:
			best_h = current_h
			best_cell = current
		for offset in _NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = current + offset
			if closed.has(neighbor):
				continue
			# The goal cell (where the player stands) is always enterable.
			if neighbor != goal_cell and _cell_blocked_cached(
				neighbor, level, obstacle_system, hazard_system, blocked_cache
			):
				continue
			var step_cost := 1.0
			if offset.x != 0 and offset.y != 0:
				# No corner cutting: block the diagonal if either side is solid.
				if _cell_blocked_cached(
					current + Vector2i(offset.x, 0),
					level, obstacle_system, hazard_system, blocked_cache
				) or _cell_blocked_cached(
					current + Vector2i(0, offset.y),
					level, obstacle_system, hazard_system, blocked_cache
				):
					continue
				step_cost = DIAGONAL_COST
			var tentative := float(g_score[current]) + step_cost
			if not g_score.has(neighbor) or tentative < float(g_score[neighbor]):
				g_score[neighbor] = tentative
				came_from[neighbor] = current
				_heap_push(heap, tentative + _heuristic(neighbor, goal_cell), neighbor)

	var end_cell := goal_cell if came_from.has(goal_cell) else best_cell
	if end_cell == start_cell:
		return
	_path = _reconstruct(came_from, start_cell, end_cell)
	_path_index = 0

func _reconstruct(
	came_from: Dictionary,
	start_cell: Vector2i,
	end_cell: Vector2i
) -> PackedVector2Array:
	var cells: Array[Vector2i] = [end_cell]
	var current := end_cell
	while current != start_cell and came_from.has(current):
		current = came_from[current]
		cells.append(current)
	cells.reverse()
	var result := PackedVector2Array()
	for cell in cells:
		result.append(_cell_to_world(cell))
	return result

func _segment_traversable(
	a: Vector2,
	b: Vector2,
	level: int,
	obstacle_system: Object,
	hazard_system: Object
) -> bool:
	var distance := a.distance_to(b)
	var step := grid_step * 0.5
	var steps := int(ceil(distance / step))
	if steps <= 0:
		return not _cell_blocked(b, level, obstacle_system, hazard_system)
	# Skip i == 0 (the enemy's own position); check every sample up to the target.
	for i in range(1, steps + 1):
		var point := a.lerp(b, float(i) / float(steps))
		if _cell_blocked(point, level, obstacle_system, hazard_system):
			return false
	return true

func _cell_blocked_cached(
	cell: Vector2i,
	level: int,
	obstacle_system: Object,
	hazard_system: Object,
	cache: Dictionary
) -> bool:
	if cache.has(cell):
		return cache[cell]
	var blocked := _cell_blocked(
		_cell_to_world(cell), level, obstacle_system, hazard_system
	)
	cache[cell] = blocked
	return blocked

func _cell_blocked(
	world: Vector2,
	level: int,
	obstacle_system: Object,
	hazard_system: Object
) -> bool:
	if (
		obstacle_system != null
		and obstacle_system.has_method("is_position_blocked")
		and obstacle_system.is_position_blocked(world)
	):
		return true
	if (
		level >= 1
		and hazard_system != null
		and hazard_system.has_method("is_void_at_world_position")
		and hazard_system.is_void_at_world_position(world)
	):
		return true
	return false

func _clear_path() -> void:
	if not _path.is_empty():
		_path = PackedVector2Array()
	_path_index = 0

func _world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(roundi(world.x / grid_step), roundi(world.y / grid_step))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * grid_step

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()

func _safe_direction(from: Vector2, to: Vector2) -> Vector2:
	var delta_vec := to - from
	if delta_vec.length_squared() <= 0.0001:
		return Vector2.ZERO
	return delta_vec.normalized()

func _heap_push(heap: Array, f: float, cell: Vector2i) -> void:
	heap.append({"f": f, "cell": cell})
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if float(heap[parent]["f"]) <= float(heap[i]["f"]):
			break
		var tmp = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent

func _heap_pop(heap: Array) -> Dictionary:
	var top: Dictionary = heap[0]
	var last: Dictionary = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var smallest := i
		var left := 2 * i + 1
		var right := 2 * i + 2
		if left < n and float(heap[left]["f"]) < float(heap[smallest]["f"]):
			smallest = left
		if right < n and float(heap[right]["f"]) < float(heap[smallest]["f"]):
			smallest = right
		if smallest == i:
			break
		var tmp = heap[smallest]
		heap[smallest] = heap[i]
		heap[i] = tmp
		i = smallest
	return top
